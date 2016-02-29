//
//  Auth.m
//  ShipHub
//
//  Created by James Howard on 2/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Auth.h"

#import "Keychain.h"
#import "JSONItem.h"
#import "Error.h"
#import "ServerConnection.h"

static NSString *const KeychainService = @"com.realartists.ShipHub";
static NSString *const KeychainAccessGroup = nil;

NSString *const AuthStateChangedNotification = @"AuthStateChanged";
NSString *const AuthStateKey = @"AuthState";
NSString *const AuthStatePreviousKey = @"AuthStatePrevious";

@interface Auth ()

@property (readwrite, strong) AuthAccount *account;
@property (readwrite, copy) NSString *token;
@property (readwrite) AuthState authState;

@end

@implementation Auth

+ (NSMutableOrderedSet *)accountsCache {
    static NSMutableOrderedSet *accountsCache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        accountsCache = [NSMutableOrderedSet orderedSet];
    });
    return accountsCache;
}

+ (Keychain *)keychain {
    static dispatch_once_t onceToken;
    static Keychain *keychain;
    dispatch_once(&onceToken, ^{
        keychain = [[Keychain alloc] initWithService:KeychainService accessGroup:KeychainAccessGroup];
    });
    return keychain;
}

+ (NSArray /*NSString*/ *)allLogins {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableOrderedSet *cache = [self accountsCache];
        [cache removeAllObjects];
        NSError *err = nil;
        NSArray *keys = [[self keychain] allAccountsReturningError:&err];
        if (err) {
            ErrLog(@"%@", err);
        }
        [cache addObjectsFromArray:keys];
    });
    return [[self accountsCache] array];
}

+ (NSString *)lastUsedLogin {
    return [[Defaults defaults] stringForKey:DefaultsLastUsedAccountKey];
}

+ (Auth *)authWithLogin:(NSString *)accountName {
    return [[self alloc] initWithLogin:accountName];
}

+ (Auth *)authForPendingLogin {
    return [[self alloc] initWithLogin:nil];
}

- (instancetype)initWithLogin:(NSString *)login {
    if (self = [super init]) {
        self.account = [[AuthAccount alloc] init];
        AuthState authState = AuthStateInvalid;
        Keychain *keychain = [[self class] keychain];
        KeychainItem *keychainItem = nil;
        if (login) {
            NSError *err = nil;
            keychainItem = [keychain itemForAccount:login error:&err];
            if (err) {
                ErrLog(@"%@", err);
            }
        }
        if (keychainItem) {
            NSString *token = keychainItem.password;
            NSData *userInfoData = keychainItem.applicationData;
            NSError *err = nil;
            NSDictionary *userInfo = [NSJSONSerialization JSONObjectWithData:userInfoData options:0 error:&err];
            if (err) {
                ErrLog(@"%@", err);
            } else {
                AuthAccount *account = [[AuthAccount alloc] initWithDictionary:userInfo];
                if (account) {
                    self.account = account;
                    self.token = token;
                    authState = AuthStateValid;
                }
            }
        }
        [self changeAuthState:authState];
    }
    return self;
}

- (void)changeAuthState:(AuthState)nextState {
    AuthState previous = self.authState;
    if (nextState != previous) {
        self.authState = nextState;
        NSDictionary *userInfo = @{ AuthStateKey : @(nextState), AuthStatePreviousKey : @(previous) };
        dispatch_block_t work = ^{ [[NSNotificationCenter defaultCenter] postNotificationName:AuthStateChangedNotification object:self userInfo:userInfo]; };
        if ([NSThread isMainThread]) {
            work();
        } else {
            dispatch_async(dispatch_get_main_queue(), work);
        }
    }
}

- (void)authorizeWithLogin:(NSString *)login
                  password:(NSString *)password
                 twoFactor:(void (^)(AuthTwoFactorContinuation))twoFactorContinuation
               chooseRepos:(AuthChooseReposContinuation)chooseReposContinuation
                completion:(void (^)(NSError *error))completion
{
    [self authorizeWithLogin:login password:password twoFactorCode:nil twoFactorContinuation:twoFactorContinuation chooseRepos:chooseReposContinuation completion:completion];
}

- (void)authorizeWithLogin:(NSString *)login
                  password:(NSString *)password
             twoFactorCode:(NSString *)twoFactor
     twoFactorContinuation:(void (^)(AuthTwoFactorContinuation))twoFactorContinuation
               chooseRepos:(AuthChooseReposContinuation)chooseReposContinuation
                completion:(void (^)(NSError *error))completion
{
    NSParameterAssert(login);
    NSParameterAssert(password);
    NSParameterAssert(twoFactorContinuation);
    NSParameterAssert(chooseReposContinuation);
    NSParameterAssert(completion);
    
    // XXX: To protect the client_secret, should probably obfuscate it.
    // Additionally, should use certificate pinning to prevent people from MITM and then snarfing it off the wire.
    
    NSDictionary *body = @{ @"scopes" : @[@"repo", @"read:org", @"admin:repo_hook", @"admin:org_hook", @"notifications", @"user:email"],
                            @"note" : @"ShipHub",
                            @"client_id" : @"55456285644976e93634",
                            @"client_secret" : @"044a8c057d8a00f023f4c19932d0fcbb77deaa57" };
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api.github.com/authorizations/clients/%@", body[@"client_id"]]]];
    req.HTTPMethod = @"PUT";
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    
    NSString *credentialStr = [NSString stringWithFormat:@"%@:%@", login, password];
    NSData *credentialData = [credentialStr dataUsingEncoding:NSUTF8StringEncoding];
    NSString *credentialB64 = [credentialData base64EncodedStringWithOptions:0];
    
    [req setValue:[NSString stringWithFormat:@"Basic %@", credentialB64] forHTTPHeaderField:@"Authorization"];
    
    if ([twoFactor length]) {
        [req setValue:twoFactor forHTTPHeaderField:@"X-GitHub-OTP"];
    }
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        
        DebugLog(@"%@", http);
        DebugLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        if (http.statusCode == 200 || http.statusCode == 201) {
            NSDictionary *reply = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            NSString *token = reply[@"token"];
            DebugLog(@"Got token %@", token);
            
            if ([token length] == 0) {
                error = [NSError shipErrorWithCode:ShipErrorCodeInvalidPassword];
            } else {
                ServerConnection *conn = [[ServerConnection alloc] initWithAuth:self];
                [conn loadAccountWithCompletion:^(AuthAccount *account, NSArray *allRepos, NSArray *chosenRepos, NSError *accountError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (accountError) {
                            ErrLog(@"%@", accountError);
                            completion(accountError);
                        } else {
                            dispatch_block_t commit = ^{
                                DebugLog(@"Committing account to keychain");
                                self.account = account;
                                self.token = token;
                                
                                KeychainItem *keychainItem = [[KeychainItem alloc] init];
                                keychainItem.account = self.account.login;
                                keychainItem.password = self.token;
                                keychainItem.applicationData = [NSJSONSerialization dataWithJSONObject:[self.account dictionaryRepresentation] options:0 error:NULL];
                                
                                NSError *keychainErr = nil;
                                [[[self class] keychain] storeItem:keychainItem error:&keychainErr];
                                [[[self class] accountsCache] insertObject:keychainItem.account atIndex:0];
                                
                                [[NSUserDefaults standardUserDefaults] setObject:self.account.login forKey:DefaultsLastUsedAccountKey];
                                
                                [self changeAuthState:AuthStateValid];
                            };
                            
                            if ([chosenRepos count] == 0) {
                                DebugLog(@"Must choose repos ...");
                                chooseReposContinuation(conn /* this creates a cycle in conn, but only temporarily */, account, allRepos, commit);
                            } else {
                                commit();
                            }
                        }
                    });
                }];
                return;
            }
        } else if (http.statusCode == 401 && [http allHeaderFields][@"X-GitHub-OTP"] != nil) {
            // need to perform two factor auth.
            dispatch_async(dispatch_get_main_queue(), ^{
                AuthTwoFactorContinuation cont = ^(NSString *code) {
                    if (!code) {
                        completion([NSError shipErrorWithCode:ShipErrorCodeInvalidPassword]);
                    } else {
                        [self authorizeWithLogin:login password:password twoFactorCode:code twoFactorContinuation:twoFactorContinuation chooseRepos:chooseReposContinuation completion:completion];
                    }
                };
                twoFactorContinuation(cont);
            });
            return;
        } else {
            ErrLog(@"Failed to get token with code %td: %@", http.statusCode, http);
            
            if (!error) {
                error = [NSError shipErrorWithCode:ShipErrorCodeInvalidPassword];
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(error);
        });
    }] resume];
}

@end

@implementation AuthAccount

- (id)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        self.login = dict[@"login"];
        self.name = dict[@"name"];
        self.identifier = dict[@"id"];
        self.extra = dict;
    }
    return self;
}

- (NSMutableDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:self.extra ?: @{}];
    d[@"login"] = self.login;
    d[@"name"] = self.name;
    d[@"id"] = self.identifier;
    return d;
}

@end

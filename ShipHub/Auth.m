//
//  Auth.m
//  ShipHub
//
//  Created by James Howard on 2/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Auth.h"

#import "Extras.h"
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
@property (readwrite, copy) NSString *ghToken;
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
        NSString *service = [NSString stringWithFormat:@"%@.%@",
                             KeychainService,
                             [[Defaults defaults] stringForKey:DefaultsServerKey]];
        keychain = [[Keychain alloc] initWithService:service accessGroup:KeychainAccessGroup];
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

- (instancetype)initWithLogin:(NSString *)login {
    if (self = [super init]) {
        self.account = [[AuthAccount alloc] init];
        Keychain *keychain = [[self class] keychain];
        KeychainItem *keychainItem = nil;
        if (login) {
            NSError *err = nil;
            keychainItem = [keychain itemForAccount:login error:&err];
            if (err && !([[err domain] isEqualToString:@"Keychain"] && [err code] == -25300 /* ignore missing item error */)) {
                ErrLog(@"%@", err);
            }
        }
        if (keychainItem) {
            NSArray *tokens = [keychainItem.password componentsSeparatedByString:@"&"];
            if ([tokens count] == 2) {
                NSString *token = tokens[0];
                NSString *ghToken = tokens[1];
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
                        self.ghToken = ghToken;
                        [self changeAuthState:AuthStateValid];
                        return self;
                    }
                }
            } else {
                NSError *err = nil;
                [keychain removeItemForAccount:login error:&err];
                if (err) {
                    ErrLog("%@", err);
                }
            }
        }
        
    }
    return nil;
}

+ (Auth *)authWithAccount:(AuthAccount *)account shipToken:(NSString *)shipToken ghToken:(NSString *)ghToken; {
    return [[self alloc] initWithAccount:account shipToken:shipToken ghToken:ghToken];
}

- (instancetype)initWithAccount:(AuthAccount *)account shipToken:(NSString *)shipToken ghToken:(NSString *)ghToken {
    NSParameterAssert(account);
    NSParameterAssert(shipToken);
    NSParameterAssert(ghToken);
    
    if (self = [super init]) {
        KeychainItem *keychainItem = [KeychainItem new];
        keychainItem.account = account.login;
        keychainItem.password = [NSString stringWithFormat:@"%@&%@", shipToken, ghToken];
        NSError *error = nil;
        keychainItem.applicationData = [NSJSONSerialization dataWithJSONObject:[account dictionaryRepresentation] options:0 error:&error];
        if (error) {
            ErrLog(@"%@", error);
            return nil;
        }
        Keychain *keychain = [[self class] keychain];

        [keychain storeItem:keychainItem error:&error];
        if (error) {
            ErrLog(@"%@", error);
            return nil;
        }
        
        self.account = account;
        self.token = shipToken;
        self.ghToken = ghToken;
        [self changeAuthState:AuthStateValid];
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

- (void)invalidate {
    [self changeAuthState:AuthStateInvalid];
}

- (BOOL)checkResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (http.statusCode == 401) {
            [self invalidate];
            return NO;
        }
    }
    return YES;
}

- (BOOL)checkError:(NSError *)error {
    if ([error isShipError] && [error code] == ShipErrorCodeNeedsAuthToken) {
        [self invalidate];
        return NO;
    }
    return YES;
}

- (void)addAuthHeadersToRequest:(NSMutableURLRequest *)request {
    [request setValue:nil forHTTPHeaderField:@"Authorization"];
    if ([[[request URL] host] hasSuffix:@"realartists.com"]) {
        // Authorisation with an 's' to work around IIS HTTP/2 bug
        [request setValue:[NSString stringWithFormat:@"token %@", self.token] forHTTPHeaderField:@"Authorisation"];
    } else {
        [request setValue:[NSString stringWithFormat:@"token %@", self.ghToken] forHTTPHeaderField:@"Authorization"];
    }
}

- (void)logout {
    Keychain *keychain = [[self class] keychain];
    NSError *err = nil;
    [keychain removeItemForAccount:self.account.login error:&err];
    if (err) {
        ErrLog("%@", err);
    }
    [self changeAuthState:AuthStateInvalid];
}

@end

@implementation AuthAccount

- (id)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        self.login = dict[@"login"];
        self.name = dict[@"name"];
        self.ghIdentifier = dict[@"ghIdentifier"];
        self.shipIdentifier = dict[@"identifier"];
        self.ghHost = dict[@"ghHost"];
        self.shipHost = dict[@"shipHost"];
        self.extra = dict;
    }
    return self;
}

- (NSMutableDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:self.extra ?: @{}];
    d[@"login"] = self.login;
    [d setOptional:self.name forKey:@"name"];
    d[@"ghIdentifier"] = self.ghIdentifier;
    d[@"shipIdentifier"] = self.shipIdentifier;
    d[@"ghHost"] = self.ghHost;
    d[@"shipHost"] = self.shipHost;
    return d;
}

@end

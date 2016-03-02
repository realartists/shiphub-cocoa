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

+ (Auth *)authWithAccount:(AuthAccount *)account token:(NSString *)token {
    return [[self alloc] initWithAccount:account token:token];
}

- (instancetype)initWithAccount:(AuthAccount *)account token:(NSString *)token {
    NSParameterAssert(account);
    NSParameterAssert(token);
    
    if (self = [super init]) {
        KeychainItem *keychainItem = [KeychainItem new];
        keychainItem.account = account.login;
        keychainItem.password = token;
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
        self.token = token;
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

- (void)checkResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        if (http.statusCode == 401) {
            [self invalidate];
        }
    }
}

- (void)checkError:(NSError *)error {
    if ([error isShipError] && [error code] == ShipErrorCodeNeedsAuthToken) {
        [self invalidate];
    }
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

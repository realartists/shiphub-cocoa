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
#import "WebSession.h"

static NSString *const KeychainService = @"com.realartists.Ship2";
static NSString *const KeychainAccessGroup = nil;

NSString *const AuthStateChangedNotification = @"AuthStateChanged";
NSString *const AuthStateKey = @"AuthState";
NSString *const AuthStatePreviousKey = @"AuthStatePrevious";

@interface Auth ()

@property (readwrite, strong) AuthAccount *account;
@property (readwrite, copy) NSString *token;
@property (readwrite, copy) NSString *ghToken;
@property (readwrite) AuthState authState;
@property (readwrite, strong) WebSession *webSession;

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
        keychain = [[Keychain alloc] initWithServicePrefix:KeychainService accessGroup:KeychainAccessGroup];
    });
    return keychain;
}

+ (NSArray<AuthAccountPair *> *)allLogins {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableOrderedSet *cache = [self accountsCache];
        [cache removeAllObjects];
        NSError *err = nil;
        NSArray<KeychainItem *> *items = [[self keychain] allAccountsReturningError:&err];
        if (err) {
            ErrLog(@"%@", err);
        }
        [cache addObjectsFromArray:[items arrayByMappingObjects:^id(KeychainItem *obj) {
            AuthAccountPair *pair = [AuthAccountPair new];
            pair.login = obj.account;
            pair.shipHost = obj.server;
            return pair;
        }]];
    });
    return [[self accountsCache] array];
}

+ (AuthAccountPair *)lastUsedLogin {
    NSArray *parts = [[Defaults defaults] objectForKey:DefaultsLastUsedAccountKey];
    if ([parts count] == 2) {
        AuthAccountPair *pair = [AuthAccountPair new];
        pair.login = parts[0];
        pair.shipHost = parts[1];
        return pair;
    }
    return nil;
}

+ (Auth *)authWithAccountPair:(AuthAccountPair *)pair {
    return [[self alloc] initWithAccountPair:pair];
}

- (instancetype)initWithAccountPair:(AuthAccountPair *)pair {
    if (self = [super init]) {
        self.account = [[AuthAccount alloc] init];
        Keychain *keychain = [[self class] keychain];
        KeychainItem *keychainItem = nil;
        if (pair.login && pair.shipHost) {
            NSError *err = nil;
            keychainItem = [keychain itemForAccount:pair.login server:pair.shipHost error:&err];
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
                        self.webSession = [[WebSession alloc] initWithAuthAccount:account];
                        [self changeAuthState:AuthStateValid];
                        return self;
                    }
                }
            } else {
                NSError *err = nil;
                [keychain removeItemForAccount:pair.login server:pair.shipHost error:&err];
                if (err) {
                    ErrLog("%@", err);
                }
            }
        }
        
    }
    return nil;
}

+ (Auth *)authWithAccount:(AuthAccount *)account shipToken:(NSString *)shipToken ghToken:(NSString *)ghToken {
    return [[self class] authWithAccount:account shipToken:shipToken ghToken:ghToken sessionCookies:nil];
}

+ (Auth *)authWithAccount:(AuthAccount *)account shipToken:(NSString *)shipToken ghToken:(NSString *)ghToken sessionCookies:(NSArray<NSHTTPCookie *> *)sessionCookies {
    return [[self alloc] initWithAccount:account shipToken:shipToken ghToken:ghToken sessionCookies:sessionCookies];
}

- (instancetype)initWithAccount:(AuthAccount *)account shipToken:(NSString *)shipToken ghToken:(NSString *)ghToken sessionCookies:(NSArray<NSHTTPCookie *> *)sessionCookies
{
    NSParameterAssert(account);
    NSParameterAssert(shipToken);
    NSParameterAssert(ghToken);
    
    if (self = [super init]) {
        KeychainItem *keychainItem = [KeychainItem new];
        keychainItem.account = account.login;
        keychainItem.server = account.shipHost;
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
        self.webSession = [[WebSession alloc] initWithAuthAccount:account initialCookies:sessionCookies];
        [self changeAuthState:AuthStateValid];
        
        [[[self class] accountsCache] addObject:[account pair]];
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
    [request setValue:[NSString stringWithFormat:@"token %@", self.ghToken] forHTTPHeaderField:@"Authorization"];
}

- (void)logout {
    Keychain *keychain = [[self class] keychain];
    AuthAccountPair *pair = [AuthAccountPair new];
    pair.login = self.account.login;
    pair.shipHost = self.account.shipHost;
    
    NSError *err = nil;
    [keychain removeItemForAccount:self.account.login server:self.account.shipHost error:&err];
    if (err) {
        ErrLog("%@", err);
    }
    
    [[[self class] accountsCache] removeObject:pair];
    [_webSession logout];
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

- (AuthAccountPair *)pair {
    AuthAccountPair *pair = [AuthAccountPair new];
    pair.login = self.login;
    pair.shipHost = self.shipHost;
    return pair;
}

@end

@implementation AuthAccountPair

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%@%@", _login, _shipHost] hash];
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[AuthAccountPair class]]) {
        AuthAccountPair *other = object;
        return [_login isEqual:other->_login] && [_shipHost isEqual:other->_shipHost];
    }
    return NO;
}

@end

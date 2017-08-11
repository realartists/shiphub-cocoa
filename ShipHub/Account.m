//
//  Account.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "AccountInternal.h"

#import "LocalAccount.h"
#import "Auth.h"

#if TARGET_REVIEWED_BY_ME
#import "RMEDataStore.h"
#else
#import "DataStore.h"
#import "MetadataStore.h"
#endif

@interface Account ()

@property (readwrite) NSString *avatarURL;
@property (readwrite) NSString *login;
@property (readwrite) NSString *name;

@property (readwrite) AccountType accountType;

@end

@implementation Account

#if TARGET_SHIP
- (instancetype)initWithLocalItem:(id)localItem {
    LocalAccount *la = localItem;
    
    if (self = [super initWithLocalItem:localItem]) {
        _avatarURL = la.avatarURL;
        _login = la.login;
        _name = la.name;
        _shipNeedsWebhookHelp = [la.shipNeedsWebhookHelp boolValue];
        
        NSString *type = la.type;
        if ([type isEqualToString:@"User"]) {
            _accountType = AccountTypeUser;
        } else if ([type isEqualToString:@"Organization"]) {
            _accountType = AccountTypeOrg;
        }
    }
    
    return self;
}
#endif

- (instancetype)initWithAuthAccount:(AuthAccount *)ac {
    if (self = [super init]) {
        self.identifier = ac.ghIdentifier;
        _login = ac.login;
        _accountType = AccountTypeUser;
    }
    return self;
}

- (instancetype)initWithDictionary:(NSDictionary *)d {
    if (self = [super initWithDictionary:d]) {
        _login = d[@"login"];
        _name = d[@"name"];
        _accountType = AccountTypeUnknown;
    }
    return self;
}

- (NSString *)type {
    switch (_accountType) {
        case AccountTypeUnknown: return nil;
        case AccountTypeOrg: return @"Organization";
        case AccountTypeUser: return @"User";
    }
}

- (NSURL *)URL {
#if TARGET_REVIEWED_BY_ME
    RMEDataStore *store = [RMEDataStore activeStore];
    Auth *auth = [store auth];
    AuthAccount *account = [auth account];
#else
    DataStore *store = [DataStore activeStore];
    Auth *auth = [store auth];
    AuthAccount *account = [auth account];
#endif
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", account.webGHHost, self.login]];
}

+ (Account *)me {
#if TARGET_REVIEWED_BY_ME
    RMEDataStore *store = [RMEDataStore activeStore];
    Auth *auth = [store auth];
    AuthAccount *account = [auth account];
    return [[Account alloc] initWithAuthAccount:account];
#else
    DataStore *store = [DataStore activeStore];
    Auth *auth = [store auth];
    NSNumber *identifier = [[auth account] ghIdentifier];
    Account *u = [[store metadataStore] accountWithIdentifier:identifier];
    if (!u) {
        u = [[self alloc] initWithAuthAccount:auth.account];
    }
    return u;
#endif
}


@end

//
//  Account.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Account.h"

#import "LocalAccount.h"
#import "DataStore.h"
#import "Auth.h"
#import "MetadataStore.h"

@implementation Account

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

- (instancetype)initWithAuthAccount:(AuthAccount *)ac {
    if (self = [super init]) {
        self.identifier = ac.ghIdentifier;
        _login = ac.login;
        _accountType = AccountTypeUser;
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

+ (Account *)me {
    DataStore *store = [DataStore activeStore];
    Auth *auth = [store auth];
    NSNumber *identifier = [[auth account] ghIdentifier];
    Account *u = [[store metadataStore] accountWithIdentifier:identifier];
    if (!u) {
        u = [[self alloc] initWithAuthAccount:auth.account];
    }
    return u;
}


@end

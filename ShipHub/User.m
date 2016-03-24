//
//  User.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "User.h"

#import "AccountInternal.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Auth.h"

@implementation User

- (instancetype)initWithAuthAccount:(AuthAccount *)ac {
    if (self = [super init]) {
        self.login = ac.login;
        self.identifier = ac.ghIdentifier;
        
    }
    return self;
}

+ (User *)me {
    DataStore *store = [DataStore activeStore];
    Auth *auth = [store auth];
    NSNumber *identifier = [[auth account] ghIdentifier];
    User *u = [[store metadataStore] userWithIdentifier:identifier];
    if (!u) {
        u = [[self alloc] initWithAuthAccount:auth.account];
    }
    return u;
}

@end

//
//  User.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "User.h"

#import "DataStore.h"
#import "MetadataStore.h"
#import "Auth.h"

@implementation User

+ (User *)me {
    DataStore *store = [DataStore activeStore];
    Auth *auth = [store auth];
    NSNumber *identifier = [[auth account] ghIdentifier];
    return [[store metadataStore] userWithIdentifier:identifier];
}

@end

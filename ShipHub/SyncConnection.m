//
//  SyncConnection.m
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "SyncConnection.h"

#import "Auth.h"

@interface SyncConnection ()

@property (strong) Auth *auth;

@end

@implementation SyncConnection

- (id)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        self.auth = auth;
    }
    return self;
}

- (void)syncWithVersions:(NSDictionary *)versions {
    
}

@end

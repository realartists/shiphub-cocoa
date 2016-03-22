//
//  Account.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Account.h"

#import "LocalAccount.h"

@implementation Account

- (instancetype)initWithLocalItem:(id)localItem {
    LocalAccount *la = localItem;
    
    if (self = [super initWithLocalItem:localItem]) {
        _avatarURL = la.avatarURL;
        _login = la.login;
        _name = la.name;
    }
    
    return self;
}

@end

//
//  Account.h
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MetadataItem.h"

typedef NS_ENUM(NSInteger, AccountType) {
    AccountTypeUnknown = 0,
    AccountTypeUser = 1,
    AccountTypeOrg = 2
};

@interface Account : MetadataItem

@property (readonly) NSString *avatarURL;
@property (readonly) NSString *login;
@property (readonly) NSString *name;

@property (readonly) AccountType accountType;
@property (readonly) NSString *type; // User, Organization, or nil

@property (readonly) BOOL shipNeedsWebhookHelp;

+ (Account *)me;

@end

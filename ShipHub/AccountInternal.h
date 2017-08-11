//
//  AccountInternal.h
//  ShipHub
//
//  Created by James Howard on 12/6/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "Account.h"

@interface Account (Internal)

@property (readwrite) NSString *avatarURL;
@property (readwrite) NSString *login;
@property (readwrite) NSString *name;

@property (readwrite) AccountType accountType;

@end

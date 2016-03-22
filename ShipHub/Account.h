//
//  Account.h
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MetadataItem.h"

@interface Account : MetadataItem

@property (readonly) NSString *avatarURL;
@property (readonly) NSString *login;
@property (readonly) NSString *name;

@end

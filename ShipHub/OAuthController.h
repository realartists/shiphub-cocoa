//
//  OAuthController.h
//  ShipHub
//
//  Created by James Howard on 8/15/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "HelloController.h"

@interface OAuthController : HelloController

- (id)initWithAuthCode:(NSString *)code;

@property (readonly, copy) NSString *code;

@end

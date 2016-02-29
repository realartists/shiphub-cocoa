//
//  TwoFactorController.h
//  ShipHub
//
//  Created by James Howard on 2/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Auth.h"
#import "AuthViewController.h"

@interface TwoFactorController : AuthViewController

- (id)initWithTwoFactorContinuation:(AuthTwoFactorContinuation)continuation;

@property (copy) AuthTwoFactorContinuation continuation;

- (void)retryCode;

@end

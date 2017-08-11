//
//  RMEAuthController.h
//  ShipHub
//
//  Created by James Howard on 8/11/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;
@protocol RMEAuthControllerDelegate;

@interface RMEAuthController : NSWindowController

@property (weak) id<RMEAuthControllerDelegate> delegate;

@end

@protocol RMEAuthControllerDelegate <NSObject>

- (void)authController:(RMEAuthController *)controller authenticated:(Auth *)auth newAccount:(BOOL)isNewAccount;

@end

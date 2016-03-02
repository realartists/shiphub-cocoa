//
//  AuthController.h
//  Ship
//
//  Created by James Howard on 6/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;
@protocol AuthControllerDelegate;

@interface AuthController : NSWindowController

@property (weak) id<AuthControllerDelegate> delegate;

@end

@protocol AuthControllerDelegate <NSObject>

- (void)authController:(AuthController *)controller authenticated:(Auth *)auth;

@end

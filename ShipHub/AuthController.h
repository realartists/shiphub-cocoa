//
//  AuthController.h
//  Ship
//
//  Created by James Howard on 6/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;

@interface AuthController : NSWindowController

@property Auth *auth;

- (IBAction)showIfNeeded:(id)sender;

- (void)showWelcomeAnimated:(BOOL)animate;

@end

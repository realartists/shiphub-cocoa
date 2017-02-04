//
//  AuthController.h
//  Ship
//
//  Created by James Howard on 6/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;
@class NavigationController;
@protocol AuthControllerDelegate;

@interface AuthController : NSWindowController

+ (AuthController *)authControllerForViewController:(NSViewController *)vc;

@property (weak) id<AuthControllerDelegate> delegate;

- (void)continueWithViewController:(NSViewController *)vc;

- (void)continueWithLaunchURL:(NSURL *)URL;

- (IBAction)showWindow:(id)sender lastAuth:(Auth *)lastAuth;

@end

@protocol AuthControllerDelegate <NSObject>

- (void)authController:(AuthController *)controller authenticated:(Auth *)auth;

@end

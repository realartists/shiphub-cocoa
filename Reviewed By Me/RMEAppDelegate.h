//
//  AppDelegate.h
//  Reviewed By Me
//
//  Created by James Howard on 8/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;

@interface RMEAppDelegate : NSObject <NSApplicationDelegate>

@property (readonly) Auth *auth;

+ (instancetype)sharedDelegate;

- (void)openURL:(NSURL *)URL;

@end


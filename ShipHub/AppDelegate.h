//
//  AppDelegate.h
//  ShipHub
//
//  Created by James Howard on 2/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;

@interface AppDelegate : NSObject <NSApplicationDelegate>

+ (instancetype)sharedDelegate;

- (void)authFinished:(Auth *)auth;

@end


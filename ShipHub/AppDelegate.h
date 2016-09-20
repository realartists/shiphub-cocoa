//
//  AppDelegate.h
//  ShipHub
//
//  Created by James Howard on 2/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;
@class OverviewController;

@interface AppDelegate : NSObject <NSApplicationDelegate>

+ (instancetype)sharedDelegate;

- (OverviewController *)defaultOverviewController;
- (OverviewController *)activeOverviewController;

- (IBAction)showBilling:(id)sender;

@end


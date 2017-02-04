//
//  WebAuthController.h
//  ShipHub
//
//  Created by James Howard on 8/15/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AuthController;

@interface WebAuthController : NSWindowController

- (id)initWithAuthController:(AuthController *)authController;

@property (copy) NSString *shipHost;
@property BOOL publicReposOnly;

- (void)show;

@end

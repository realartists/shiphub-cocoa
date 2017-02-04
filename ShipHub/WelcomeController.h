//
//  WelcomeController.h
//  ShipHub
//
//  Created by James Howard on 8/15/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WelcomeController : NSViewController

@property (copy) NSString *shipHost;
@property (copy) NSString *ghHost;
@property BOOL publicReposOnly;

@end

//
//  IssueLockController.h
//  ShipHub
//
//  Created by James Howard on 7/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef void (^IssueLockControllerAction)(BOOL lock);

@interface IssueLockController : NSViewController

@property (nonatomic) BOOL currentlyLocked;

@property (copy) IssueLockControllerAction actionBlock;

@end

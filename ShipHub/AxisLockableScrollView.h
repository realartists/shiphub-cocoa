//
//  AxisLockableScrollView.h
//  ShipHub
//
//  Created by James Howard on 5/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AxisLockableScrollView : NSScrollView

@property BOOL disableHorizontalScrolling;
@property BOOL disableVerticalScrolling;

@end

//
//  AxisLockableScrollView.m
//  ShipHub
//
//  Created by James Howard on 5/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "AxisLockableScrollView.h"

@implementation AxisLockableScrollView

- (void)scrollWheel:(NSEvent *)theEvent {
    if (_disableHorizontalScrolling && _disableVerticalScrolling) {
        [self.nextResponder scrollWheel:theEvent];
        return;
    }
    
    CGFloat absX = fabs(theEvent.scrollingDeltaX);
    CGFloat absY = fabs(theEvent.scrollingDeltaY);
    
    if (_disableHorizontalScrolling) {
        if (absX > absY) {
            [self.nextResponder scrollWheel:theEvent];
            return;
        }
    } else if (_disableVerticalScrolling) {
        if (absX < absY) {
            [self.nextResponder scrollWheel:theEvent];
            return;
        }
    }
    
    [super scrollWheel:theEvent];
}

@end

//
//  LabelButton.m
//  Ship
//
//  Created by James Howard on 9/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "LabelButton.h"

@implementation LabelButton

- (NSView *)hitTest:(NSPoint)aPoint {
    return nil;
}

- (NSSize)intrinsicContentSize {
    if (self.hidden || [self.title length] == 0) {
        return CGSizeZero;
    } else {
        return [super intrinsicContentSize];
    }
}

@end

//
//  ChevronButton.m
//  Ship
//
//  Created by James Howard on 6/16/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "ChevronButton.h"

@implementation ChevronButton

- (void)awakeFromNib {
    [super awakeFromNib];
    [self sendActionOn:NSLeftMouseDownMask];
}

- (void)drawRect:(NSRect)dirtyRect {
    CGRect bounds = self.bounds;
        
    CGFloat lineWidth = 2.0;

    CGRect rect = CGRectInset(bounds, lineWidth*3, lineWidth*3);
    rect.size.height = round(rect.size.width * 0.5);
    rect.origin.y = round((bounds.size.height - rect.size.height) / 2.0);
    
    if (self.highlighted) {
        [[NSColor darkGrayColor] setStroke];
    } else {
        [[NSColor grayColor] setStroke];
    }
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect))];
    [path lineToPoint:CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect))];
    [path lineToPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect))];
    [path setLineWidth:lineWidth];
    [path setLineCapStyle:NSRoundLineCapStyle];
    [path setLineJoinStyle:NSRoundLineJoinStyle];
    
    [path stroke];
}

@end

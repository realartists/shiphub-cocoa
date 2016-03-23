//
//  Sparkline.m
//  Ship
//
//  Created by James Howard on 9/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "Sparkline.h"

@implementation Sparkline

- (void)setValues:(NSArray *)values {
    _values = values;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    if ([_values count] < 2) {
        return;
    }
    
    CGRect bounds = self.bounds;
    CGFloat w = bounds.size.width;
    CGFloat h = bounds.size.height;
    CGFloat min = [[_values firstObject] doubleValue];
    CGFloat max = [[_values firstObject] doubleValue];
    
    if (w <= 0 || h <= 0) {
        return;
    }
    
    for (NSNumber *n in _values) {
        CGFloat v = [n doubleValue];
        min = MIN(v, min);
        max = MAX(v, max);
    }
    
    CGFloat minY = 1.0;
    CGFloat maxY = h-1.0;
    CGFloat midY = h / 2.0;
    
    // Limit slope for sparklines with overall delta < pixel resolution of the view
    if ((max - min) < h - 2.0) {
        minY = midY - ((max - min) / 2.0);
        maxY = midY + ((max - min) / 2.0);
    }
    
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSInteger i = 0;
    NSInteger c = [_values count] - 1;
    for (NSNumber *n in _values) {
        CGFloat v = [n doubleValue];
        CGFloat x = 1.0 + ((w-2.0) * ((CGFloat)i / (CGFloat)c));
        CGFloat y = 0;
        if (max == min) {
            y = midY;
        } else {
            y = minY + ((maxY - minY) * ((v - min) / (max - min)));
        }
        
        CGPoint p = CGPointMake(x, y);
        if (i == 0) {
            [path moveToPoint:p];
        } else {
            [path lineToPoint:p];
        }
        
        i++;
    }
    
    [[NSColor darkGrayColor] setStroke];
    [path setLineWidth:1.0];
    [path setLineCapStyle:NSRoundLineCapStyle];
    [path setLineJoinStyle:NSRoundLineJoinStyle];
    
    [path stroke];
}

@end

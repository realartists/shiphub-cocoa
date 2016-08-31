//
//  NSImage+Icons.m
//  Ship
//
//  Created by James Howard on 8/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "NSImage+Icons.h"

#import "AppKitExtras.h"

@implementation NSImage (Icons)

+ (NSImage *)sidebarIcon {
    return [NSImage imageNamed:@"NSSidebarTemplate"];
}

+ (NSImage *)advancedSearchIcon {
    static dispatch_once_t onceToken;
    static NSImage *image = nil;
    dispatch_once(&onceToken, ^{
        image = [[NSImage alloc] initWithSize:CGSizeMake(18.0, 18.0)];
        [image lockFocusFlipped:YES];
        
        // Draw the circle, slightly above center and slightly left of center
        CGRect circleRect = CGRectMake(1.0, 2.0, 11.0, 11.0);
        NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:circleRect];
        [[NSColor blackColor] setStroke];
        [circle stroke];
        
        // Inside the circle, draw a +
        NSBezierPath *plus = [NSBezierPath bezierPath];
        [plus moveToPoint:CGPointMake(CGRectGetMidX(circleRect), CGRectGetMinY(circleRect) + 3.0)];
        [plus lineToPoint:CGPointMake(CGRectGetMidX(circleRect), CGRectGetMaxY(circleRect) - 3.0)];
        [plus moveToPoint:CGPointMake(CGRectGetMinX(circleRect) + 3.0, CGRectGetMidY(circleRect))];
        [plus lineToPoint:CGPointMake(CGRectGetMaxX(circleRect) - 3.0, CGRectGetMidY(circleRect))];
        [plus stroke];
        
        // Draw the handle coming out of the circle
        NSBezierPath *handle = [NSBezierPath bezierPath];
        [handle moveToPoint:CGPointMake(12.0 - 1.65, 13.0 - 1.25)];
        [handle lineToPoint:CGPointMake(14.0, 15.0)];
        [handle setLineCapStyle:NSRoundLineCapStyle];
        [handle stroke];
        
        [image unlockFocus];
        [image setTemplate:YES];
    });
    return image;
}

+ (NSImage *)searchResultsIcon {
    return [NSImage imageNamed:NSImageNameListViewTemplate];
}

+ (NSImage *)threePaneIcon {
    return [NSImage imageNamed:NSImageNameColumnViewTemplate];
}

+ (NSImage *)chartingIcon {
    static dispatch_once_t onceToken;
    static NSImage *image = nil;
    dispatch_once(&onceToken, ^{
        image = [NSImage imageNamed:@"858-line-chart"];
        [image setTemplate:YES];
    });
    return image;
}

+ (NSImage *)watchStarOff {
    static dispatch_once_t onceToken;
    static NSImage *image = nil;
    dispatch_once(&onceToken, ^{
        image = [NSImage imageNamed:@"watch_star_off"];
        [image setTemplate:YES];
    });
    return image;
}

+ (NSImage *)watchStarOffHover {
    static dispatch_once_t onceToken;
    static NSImage *image = nil;
    dispatch_once(&onceToken, ^{
        image = [NSImage imageNamed:@"watch_star_off_hover"];
        [image setTemplate:YES];
    });
    return image;
}

+ (NSImage *)watchStarOn {
    static dispatch_once_t onceToken;
    static NSImage *image = nil;
    dispatch_once(&onceToken, ^{
        image = [NSImage imageNamed:@"watch_star_on"];
        [image setTemplate:YES];
    });
    return image;
}

+ (NSImage *)watchStarOnHover {
    static dispatch_once_t onceToken;
    static NSImage *image = nil;
    dispatch_once(&onceToken, ^{
        image = [NSImage imageNamed:@"watch_star_on_hover"];
        [image setTemplate:YES];
    });
    return image;
}

+ (NSImage *)overviewIconNamed:(NSString *)name {
    static NSMutableDictionary *cache = nil;
    if (!cache) {
        cache = [NSMutableDictionary new];
    }
    NSImage *result = cache[name];
    if (!result) {
        NSImage *base = [NSImage imageNamed:name];
        [base setTemplate:YES];
        result = base;
        cache[name] = result;
    }
    return result;
}

@end

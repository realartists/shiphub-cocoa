//
//  PRNavigationToolbarItem.m
//  ShipHub
//
//  Created by James Howard on 3/8/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRNavigationToolbarItem.h"

#import "Extras.h"

@interface PRNavigationToolbarSegmentedControl : NSSegmentedControl

@end

@interface PRNavigationToolbarItem () {
    __weak id my_target;
}

@property (strong) NSSegmentedControl *segmented;

@end

@implementation PRNavigationToolbarItem

- (void)configureView {
    [self setLabel:NSLocalizedString(@"Navigation", nil)];
    
    NSInteger segmentCount = 2;
    CGFloat segmentWidth = 23;
    CGSize size = CGSizeMake(segmentWidth*segmentCount, 23);
    _segmented  = [[PRNavigationToolbarSegmentedControl alloc] initWithFrame:(CGRect){ .origin = CGPointZero, .size = size }];
    _segmented.segmentCount = segmentCount;
    _segmented.segmentStyle = NSSegmentStyleSeparated;
    [_segmented setWidth:segmentWidth forSegment:0];
    [_segmented setWidth:segmentWidth forSegment:1];
    [_segmented.cell setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    
    NSImage *downArrow = [NSImage imageNamed:@"DownArrow"];
    downArrow.template = YES;
    NSImage *upArrow = [NSImage imageNamed:@"UpArrow"];
    upArrow.template = YES;
    
    [_segmented setImage:downArrow forSegment:1];
    [_segmented setImage:upArrow forSegment:0];
    
    [[_segmented cell] setToolTip:NSLocalizedString(@"Next Thing (⌃⌘↓)", nil) forSegment:1];
    [[_segmented cell] setToolTip:NSLocalizedString(@"Previous Thing (⌃⌘↑)", nil) forSegment:0];
    
    NSMenu *nextMenu = [NSMenu new];
    [nextMenu addItemWithTitle:NSLocalizedString(@"Next Change", nil) action:@selector(nextChange:) keyEquivalent:@"d"];
    [nextMenu addItemWithTitle:NSLocalizedString(@"Next Comment", nil) action:@selector(nextComment:) keyEquivalent:@"m"];
    [nextMenu addItemWithTitle:NSLocalizedString(@"Next File", nil) action:@selector(nextFile:) keyEquivalent:@"]"];
    
    NSMenu *prevMenu = [NSMenu new];
    NSMenuItem *item = [prevMenu addItemWithTitle:NSLocalizedString(@"Previous Change", nil) action:@selector(previousChange:) keyEquivalent:@"d"];
    item.keyEquivalentModifierMask = NSShiftKeyMask;
    item = [prevMenu addItemWithTitle:NSLocalizedString(@"Previous Comment", nil) action:@selector(previousComment:) keyEquivalent:@"m"];
    item.keyEquivalentModifierMask = NSShiftKeyMask;
    [prevMenu addItemWithTitle:NSLocalizedString(@"Previous File", nil) action:@selector(previousFile:) keyEquivalent:@"["];
    
    [_segmented setMenu:nextMenu forSegment:1];
    [_segmented setMenu:prevMenu forSegment:0];
    
    _segmented.trackingMode = NSSegmentSwitchTrackingMomentary;
    
    CGSize overallSize = size;
    overallSize.width += 10.0;
    overallSize.height += 2.0;
    self.minSize = overallSize;
    self.maxSize = overallSize;
    self.view = _segmented;
    
    _segmented.action = @selector(segmentPress:);
    _segmented.target = self;
}

- (void)setTarget:(id)target {
    my_target = target;
}

- (id)target {
    return my_target;
}

- (IBAction)segmentPress:(id)sender {
    if (_segmented.selectedSegment == 1) {
        [self sendAction:@selector(nextThing:) toTarget:self.target];
    } else if (_segmented.selectedSegment == 0) {
        [self sendAction:@selector(previousThing:) toTarget:self.target];
    }
}

@end

@implementation PRNavigationToolbarSegmentedControl {
    NSUInteger _hoverMask;
    NSTrackingArea *_moveTracking;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_moveTracking) {
        [self removeTrackingArea:_moveTracking];
    }
    _moveTracking = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited|NSTrackingMouseMoved|NSTrackingActiveInKeyWindow owner:self userInfo:nil];
    [self addTrackingArea:_moveTracking];
}

- (void)mouseEntered:(NSEvent *)event {
    [super mouseEntered:event];
    [self updateHoverMask:event];
}

- (void)mouseExited:(NSEvent *)event {
    [super mouseExited:event];
    [self updateHoverMask:event];
}

- (void)mouseMoved:(NSEvent *)event {
    [super mouseMoved:event];
    [self updateHoverMask:event];
}

static CGFloat widthFudge = 2.0;
static CGFloat padding = 1.0;

- (CGRect)rectForSegment:(NSUInteger)segment {
    CGFloat x = 0;
    for (NSUInteger i = 0; i < segment; i++) {
        x += [self widthForSegment:i];
        x += widthFudge;
        x += padding;
    }
    return CGRectMake(x, 0, [self widthForSegment:segment] + widthFudge, self.bounds.size.height);
}

- (void)updateHoverMask:(NSEvent *)event {
    CGPoint loc = [event locationInWindow];
    loc = [self convertPoint:loc fromView:nil];
    
    NSUInteger mask = 0;
    CGRect b = self.bounds;
    if (CGRectContainsPoint(b, loc)) {
        CGFloat x = 0;
        for (NSUInteger i = 0; i < self.segmentCount; i++) {
            CGFloat w = [self widthForSegment:i] + widthFudge;
            CGRect sb = CGRectMake(x, 0, w, b.size.height);
            x += w + padding;
            if (CGRectContainsPoint(sb, loc)) {
                mask = 1 << i;
                break;
            }
        }
    }
    
    if (_hoverMask != mask) {
        _hoverMask = mask;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSGraphicsContext currentContext] saveGraphicsState];
    [super drawRect:dirtyRect];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
    
    if (_hoverMask != 0) {
        NSUInteger segment = 0;
        NSUInteger mask = _hoverMask;
        while (mask != 1) {
            segment++;
            mask >>= 1;
        }
        
        CGRect sb = [self rectForSegment:segment];
        
        CGRect rect = CGRectMake(CGRectGetMaxX(sb) - 6.0,
                                 CGRectGetMaxY(sb) - 6.0,
                                 6.0,
                                 3.0);
        
        if (self.highlighted) {
            [[NSColor darkGrayColor] setFill];
        } else {
            [[NSColor grayColor] setFill];
        }
        
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect))];
        [path lineToPoint:CGPointMake(CGRectGetMidX(rect), CGRectGetMaxY(rect))];
        [path lineToPoint:CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect))];
        [path setLineCapStyle:NSRoundLineCapStyle];
        [path setLineJoinStyle:NSRoundLineJoinStyle];
        
        [path fill];
    }
}

@end

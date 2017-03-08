//
//  PRNavigationToolbarItem.m
//  ShipHub
//
//  Created by James Howard on 3/8/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRNavigationToolbarItem.h"

#import "Extras.h"

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
    _segmented  = [[NSSegmentedControl alloc] initWithFrame:(CGRect){ .origin = CGPointZero, .size = size }];
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

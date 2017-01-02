//
//  ButtonToolbarItem.m
//  Ship
//
//  Created by James Howard on 6/23/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "ButtonToolbarItem.h"

@interface ButtonToolbarItem ()

@property (strong) NSSegmentedControl *segmented;

@end

@implementation ButtonToolbarItem

- (void)configureView {
    CGSize size = CGSizeMake(36, 23);     // Same as Mail uses for its toolbar buttons.
    _segmented  = [[NSSegmentedControl alloc] initWithFrame:(CGRect){ .origin = CGPointZero, .size = size }];
    _segmented.segmentCount = 1;
    [_segmented setWidth:size.width forSegment:0];
    [_segmented.cell setTrackingMode:NSSegmentSwitchTrackingMomentary];
    
    CGSize overallSize = size;
    overallSize.width += 10.0;
    overallSize.height += 2.0;
    self.minSize = overallSize;
    self.maxSize = overallSize;
    self.view = _segmented;
}

- (void)setButtonImage:(NSImage *)image {
    [_segmented setImage:image forSegment:0];
}

- (NSImage *)buttonImage {
    return [_segmented imageForSegment:0];
}

- (void)setTrackingMode:(NSSegmentSwitchTracking)trackingMode {
    [_segmented.cell setTrackingMode:trackingMode];
}

- (NSSegmentSwitchTracking)trackingMode {
    return [_segmented.cell trackingMode];
}

- (BOOL)isOn {
    return [_segmented isSelectedForSegment:0];
}

- (void)setOn:(BOOL)on {
    [_segmented setSelected:on forSegment:0];
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    if (_grayWhenDisabled) {
        [_segmented setEnabled:enabled];
    } else {
        _segmented.animator.hidden = !enabled;
    }
}

@end

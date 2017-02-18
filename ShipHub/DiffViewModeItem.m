//
//  DiffViewModeItem.m
//  ShipHub
//
//  Created by James Howard on 2/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "DiffViewModeItem.h"

@interface DiffViewModeItem () {
    DiffViewMode _savedMode;
}

@property (strong) NSSegmentedControl *segmented;

@end

@implementation DiffViewModeItem

- (void)configureView {
    [self setLabel:NSLocalizedString(@"Diff Style", nil)];
    
    NSInteger segmentCount = 2;
    CGFloat segmentWidth = 36;
    CGSize size = CGSizeMake(segmentWidth*segmentCount, 23);
    _segmented  = [[NSSegmentedControl alloc] initWithFrame:(CGRect){ .origin = CGPointZero, .size = size }];
    _segmented.segmentCount = segmentCount;
    [_segmented setWidth:segmentWidth forSegment:0];
    [_segmented setWidth:segmentWidth forSegment:1];
    [_segmented.cell setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    
    NSImage *unifiedImage = [NSImage imageNamed:@"Unified Diff"];
    unifiedImage.template = YES;
    NSImage *splitDiff = [NSImage imageNamed:@"Split Diff"];
    splitDiff.template = YES;
    
    [_segmented setImage:splitDiff forSegment:0];
    [_segmented setImage:unifiedImage forSegment:1];
    [_segmented setSelectedSegment:0];
    
    [[_segmented cell] setToolTip:NSLocalizedString(@"Side By Side Diff", nil) forSegment:0];
    [[_segmented cell] setToolTip:NSLocalizedString(@"Unified Diff", nil) forSegment:1];
    
    CGSize overallSize = size;
    overallSize.width += 10.0;
    overallSize.height += 2.0;
    self.minSize = overallSize;
    self.maxSize = overallSize;
    self.view = _segmented;
}

- (DiffViewMode)mode {
    if (!self.enabled) {
        return _savedMode;
    } else {
        return (DiffViewMode)_segmented.selectedSegment;
    }
}

- (void)setMode:(DiffViewMode)mode {
    _savedMode = mode;
    if (self.enabled) {
        [_segmented setSelectedSegment:(NSInteger)mode];
    }
}

- (void)setEnabled:(BOOL)enabled {
    if (self.enabled != enabled) {
        id target = _segmented.target;
        _segmented.target = nil;
        if (!enabled) {
            _savedMode = [self mode];
            [_segmented setSelectedSegment:(NSInteger)DiffViewModeUnified];
        } else {
            [_segmented setSelectedSegment:_savedMode];
        }
        _segmented.target = target;
        _segmented.enabled = enabled;
        [super setEnabled:enabled];
    }
}

@end

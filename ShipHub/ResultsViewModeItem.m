//
//  ResultsViewModeItem.m
//  Ship
//
//  Created by James Howard on 8/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "ResultsViewModeItem.h"
#import "NSImage+Icons.h"

@interface ResultsViewModeItem ()

@property (strong) NSSegmentedControl *segmented;

@end

@implementation ResultsViewModeItem

- (void)configureView {
    CGSize size = CGSizeMake(72, 23);
    _segmented  = [[NSSegmentedControl alloc] initWithFrame:(CGRect){ .origin = CGPointZero, .size = size }];
    _segmented.segmentCount = 2;
    [_segmented setWidth:36 forSegment:0];
    [_segmented setWidth:36 forSegment:1];
    [_segmented.cell setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    
    [_segmented setImage:[NSImage searchResultsIcon] forSegment:0];
    [_segmented setImage:[NSImage chartingIcon] forSegment:1];
    [_segmented setSelectedSegment:0];

    [[_segmented cell] setToolTip:NSLocalizedString(@"List Items", nil) forSegment:0];
    [[_segmented cell] setToolTip:NSLocalizedString(@"Chart Items", nil) forSegment:1];
    
    CGSize overallSize = size;
    overallSize.width += 8.0;
    overallSize.height += 4.0;
    self.minSize = overallSize;
    self.maxSize = overallSize;
    self.view = _segmented;
}

- (void)setMode:(ResultsViewMode)mode {
    [_segmented setSelectedSegment:(NSInteger)mode];
}

- (ResultsViewMode)mode {
    NSInteger mode = [_segmented selectedSegment];
    if (mode < ResultsViewModeList) return ResultsViewModeList;
    else if (mode > ResultsViewModeChart) return ResultsViewModeChart;
    else return (ResultsViewMode)mode;
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    _segmented.animator.hidden = !enabled;
}

- (void)setChartEnabled:(BOOL)chartEnabled {
    _chartEnabled = chartEnabled;
    if (!_chartEnabled) {
        if ([self mode] == ResultsViewModeChart) {
            [self setMode:ResultsViewModeList];
            [_segmented sendAction:_segmented.action to:_segmented.target];
        }
    }
    [_segmented setEnabled:_chartEnabled forSegment:ResultsViewModeChart];
}

@end

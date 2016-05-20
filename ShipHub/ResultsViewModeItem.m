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
    NSInteger segmentCount = 4;
    CGFloat segmentWidth = 36;
    CGSize size = CGSizeMake(segmentWidth*segmentCount, 23);
    _segmented  = [[NSSegmentedControl alloc] initWithFrame:(CGRect){ .origin = CGPointZero, .size = size }];
    _segmented.segmentCount = segmentCount;
    for (NSInteger i = 0; i < segmentCount; i++) {
        [_segmented setWidth:segmentWidth forSegment:i];
    }
    [_segmented.cell setTrackingMode:NSSegmentSwitchTrackingSelectOne];
    
    //[(NSSegmentedCell *)[_segmented cell] setImageScaling:NSImageScaleAxesIndependently forSegment:0];
    [_segmented setImage:[NSImage partitionsIcon] forSegment:0];
    [_segmented setImage:[NSImage searchResultsIcon] forSegment:1];
    [_segmented setImage:[NSImage threePaneIcon] forSegment:2];
    [_segmented setImage:[NSImage chartingIcon] forSegment:3];
    [_segmented setSelectedSegment:2];

    [[_segmented cell] setToolTip:NSLocalizedString(@"Issue Cards", nil) forSegment:0];
    [[_segmented cell] setToolTip:NSLocalizedString(@"Issue List", nil) forSegment:1];
    [[_segmented cell] setToolTip:NSLocalizedString(@"Issue Browser", nil) forSegment:2];
    [[_segmented cell] setToolTip:NSLocalizedString(@"Progress Chart", nil) forSegment:3];
    
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
    if (mode < ResultsViewModePartition) return ResultsViewModePartition;
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

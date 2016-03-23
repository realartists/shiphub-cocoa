//
//  ResultsViewModeItem.h
//  Ship
//
//  Created by James Howard on 8/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "CustomToolbarItem.h"

typedef NS_ENUM(NSInteger, ResultsViewMode) {
    ResultsViewModeList,
    ResultsViewModeChart
};

@interface ResultsViewModeItem : CustomToolbarItem

@property (nonatomic, assign) ResultsViewMode mode;

@property (nonatomic, assign, getter=isChartEnabled) BOOL chartEnabled;

@end

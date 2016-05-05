//
//  ChartConfig.h
//  Ship
//
//  Created by James Howard on 11/2/15.
//  Copyright © 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ChartDateRangeType) {
    ChartDateRangeTypeRelative,
    ChartDateRangeTypeAbsolute
};

@interface ChartConfig : NSObject <NSCopying>

@property ChartDateRangeType dateRangeType;

@property NSDate *startDate;
@property NSDate *endDate;

@property NSInteger daysBack;

@property NSString *partitionKeyPath;

- (void)saveToDefaults;
+ (void)clearDefaults;

+ (ChartConfig *)defaultConfig;

@end


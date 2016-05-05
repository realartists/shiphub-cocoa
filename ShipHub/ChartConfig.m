//
//  ChartConfig.m
//  Ship
//
//  Created by James Howard on 11/2/15.
//  Copyright © 2015 Real Artists, Inc. All rights reserved.
//

#import "ChartConfig.h"

#import "Extras.h"

@implementation ChartConfig

- (id)copyWithZone:(NSZone *)zone {
    ChartConfig *c = [ChartConfig new];
    c.dateRangeType = self.dateRangeType;
    c.daysBack = self.daysBack;
    c.startDate = self.startDate;
    c.endDate = self.endDate;
    c.partitionKeyPath = self.partitionKeyPath;
    return c;
}

+ (void)clearDefaults {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ChartConfig"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveToDefaults {
    NSMutableDictionary *d = [NSMutableDictionary new];
    
    d[@"dateRangeType"] = @(_dateRangeType);
    [d setOptional:_startDate forKey:@"startDate"];
    [d setOptional:_endDate forKey:@"endDate"];
    d[@"daysBack"] = @(_daysBack);
    
    [d setOptional:_partitionKeyPath forKey:@"partitionKeyPath"];
    
    [[NSUserDefaults standardUserDefaults] setObject:d forKey:@"ChartConfig"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (ChartConfig *)defaultConfig {
    NSDictionary *d = [[NSUserDefaults standardUserDefaults] objectForKey:@"ChartConfig"];
    
    ChartConfig *c = [ChartConfig new];
    if (!d) {
        c.dateRangeType = ChartDateRangeTypeRelative;
        c.daysBack = 90;
        c.partitionKeyPath = nil;
    } else {
        c.dateRangeType = [d[@"dateRangeType"] integerValue];
        c.daysBack = [d[@"daysBack"] integerValue];
        c.startDate = d[@"startDate"];
        c.endDate = d[@"endDate"];
        c.partitionKeyPath = d[@"partitionKeyPath"];
    }
    return c;
}

@end

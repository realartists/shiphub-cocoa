//
//  TimeRemainingFormatter.h
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TimeRemainingFormatter : NSDateFormatter

- (NSTimeInterval)timerUpdateIntervalFromDate:(NSDate *)date;

@end

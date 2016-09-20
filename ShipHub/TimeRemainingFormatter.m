//
//  TimeRemainingFormatter.m
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "TimeRemainingFormatter.h"

@implementation TimeRemainingFormatter

- (NSString *)stringFromDate:(NSDate *)date {
    NSTimeInterval diff = [date timeIntervalSinceNow];
    
    NSInteger daysRemaining = round(diff / (24.0 * 60.0 * 60.0));
    NSInteger hoursRemaining = round(diff / (60.0 * 60.0));
    NSInteger minutesRemaining = round(diff / 60.0);
    NSInteger secondsRemaining = round(diff);
    
    if (diff <= 1.0) {
        return NSLocalizedString(@"No time remaining", nil);
    }
    
    if (daysRemaining == 0) {
        if (hoursRemaining == 0) {
            if (minutesRemaining == 0) {
                if (secondsRemaining == 1) {
                    return NSLocalizedString(@"1 second remaining", nil);
                } else {
                    return [NSString localizedStringWithFormat:NSLocalizedString(@"%td seconds remaining", nil), secondsRemaining];
                }
            } else if (minutesRemaining == 1) {
                return NSLocalizedString(@"1 minute remaining", nil);
            } else {
                return [NSString localizedStringWithFormat:NSLocalizedString(@"%td minutes remaining", nil), minutesRemaining];
            }
        } else if (hoursRemaining == 1) {
            return NSLocalizedString(@"1 hour remaining", nil);
        } else {
            return [NSString localizedStringWithFormat:NSLocalizedString(@"%td hours remaining", nil), hoursRemaining];
        }
    } else if (daysRemaining == 1) {
        return NSLocalizedString(@"1 day remaining", nil);
    } else {
        return [NSString localizedStringWithFormat:NSLocalizedString(@"%td days remaining", nil), daysRemaining];
    }
}

- (NSTimeInterval)timerUpdateIntervalFromDate:(NSDate *)date {
    NSTimeInterval diff = [date timeIntervalSinceNow];
    
    NSInteger daysRemaining = round(diff / (24.0 * 60.0 * 60.0));
    NSInteger hoursRemaining = round(diff / (60.0 * 60.0));
    NSInteger minutesRemaining = round(diff / 60.0);
    
    if (diff <= 1.0) {
        return [[NSDate distantFuture] timeIntervalSinceNow];
    }
    
    NSTimeInterval updateInterval = 60.0 * 60.0;
    if (daysRemaining == 0) {
        updateInterval = 30.0 * 60.0;
        if (hoursRemaining == 0) {
            updateInterval = 30.0;
            if (minutesRemaining == 0) {
                updateInterval = 0.5;
            }
        }
    }
    
    return updateInterval;
}

@end

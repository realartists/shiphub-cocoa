//
//  TimeSeries.h
//  ShipHub
//
//  Created by James Howard on 5/4/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Issue;

@interface TimeSeries : NSObject

- (id)initWithPredicate:(NSPredicate *)predicate startDate:(NSDate *)startDate endDate:(NSDate *)endDate;

@property (readonly) NSPredicate *predicate;

@property (readonly) NSDate *startDate;
@property (readonly) NSDate *endDate;

@property NSArray<Issue *> *records;

@property (readonly) NSArray<TimeSeries *> *intervals;

- (void)selectRecordsFrom:(NSArray<Issue *> *)records;
- (void)generateIntervalsWithCalendarUnit:(NSCalendarUnit)unit;

// Returns an edited version of queryPredicate that searches for open, closed, or existing issues within the date range given. The existing queryPredicate is examined to see if it is for all issues, open issues, or closed issues, and it is rewritten to drop that clause and then is ANDed with the appropriate range predicate given by the predicateFromStartDate:untilEndDate:open: method.
+ (NSPredicate *)timeSeriesPredicateWithPredicate:(NSPredicate *)queryPredicate startDate:(NSDate *)startDate endDate:(NSDate *)endDate;

+ (NSPredicate *)predicateWithoutState:(NSPredicate *)p; // strip out any state or closed comparison predicates

@end

//
//  TimeSeries.m
//  ShipHub
//
//  Created by James Howard on 5/4/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "TimeSeries.h"

#import "Extras.h"
#import "Issue.h"
#import "NSPredicate+Extras.h"

@interface TimeSeries ()

@property (readwrite, strong) NSNumber *open;

@property (readwrite, strong) NSPredicate *predicate;

@property (readwrite, strong) NSDate *startDate;
@property (readwrite, strong) NSDate *endDate;

@property (readwrite, strong) NSArray<TimeSeries *> *intervals;

@end

@implementation TimeSeries

- (id)initWithPredicate:(NSPredicate *)predicate startDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    if (self = [super init]) {
        self.predicate = predicate;
        self.startDate = startDate;
        self.endDate = endDate;
        NSNumber *open;
        [TimeSeries timeSeriesPredicateWithPredicate:predicate startDate:startDate endDate:endDate open:&open];
        _open = open;
    }
    return self;
}

// Returns a predicate for querying Issues in this range matching issueState
//
// open is one of @YES, @NO, or nil:
//  YES - Query issues that are ever open in the date range given
//   NO - Query issues that are ever closed in the date range given
//  nil - Query issues that exist in the date range given
+ (NSPredicate *)predicateFromStartDate:(NSDate *)startDate untilEndDate:(NSDate *)endDate open:(NSNumber *)open
{
    NSParameterAssert(startDate);
    NSParameterAssert(endDate);
    
    NSString *base = nil;
    
    if (open == nil) {
        // Issues that existed at some point in the interval
        base = @"(createdAt <= $endDate)";
    } else if ([open boolValue] == YES) {
        // Issues that were open at some point in the interval
        base =
        @"(createdAt <= $endDate) "
        @"AND (closedAt = nil OR closedAt >= $startDate)";
    } else /* [open boolValue] == NO */ {
        // Issues that were closed at some point in the interval
        base =
        @"(createdAt <= $endDate) "
        @"AND (closedAt != nil AND closedAt <= $endDate)";
    }
    
    return [[NSPredicate predicateWithFormat:base] predicateWithSubstitutionVariables:@{ @"startDate": startDate, @"endDate": endDate}];
}

+ (NSPredicate *)_fastPredicateFromStartDate:(NSDate *)startDate untilEndDate:(NSDate *)endDate open:(NSNumber *)open {
    NSParameterAssert(startDate);
    NSParameterAssert(endDate);
    
    BOOL (^pblock)(Issue *i, NSDictionary *x);
    
    if (open == nil) {
        // Issues that existed at some point in the interval
        pblock = ^BOOL(Issue *i, NSDictionary *x) {
            return i.createdAt.timeIntervalSinceReferenceDate <= endDate.timeIntervalSinceReferenceDate;
        };
    } else if ([open boolValue] == YES) {
        // Issues that were open at some point in the interval
        pblock = ^BOOL(Issue *i, NSDictionary *x) {
            return (i.createdAt.timeIntervalSinceReferenceDate <= endDate.timeIntervalSinceReferenceDate)
                && (i.closedAt == nil || i.closedAt.timeIntervalSinceReferenceDate >= startDate.timeIntervalSinceReferenceDate);
        };
    } else /* [open boolValue] == NO */ {
        // Issues that were closed at some point in the interval
        pblock = ^BOOL(Issue *i, NSDictionary *x) {
            return (i.createdAt.timeIntervalSinceReferenceDate <= endDate.timeIntervalSinceReferenceDate)
            && (i.closedAt == nil || i.closedAt.timeIntervalSinceReferenceDate <= endDate.timeIntervalSinceReferenceDate);
        };
    }
    
    return [NSPredicate predicateWithBlock:pblock];
}

static BOOL isStatePredicate(NSPredicate *predicate, BOOL *isOpenValue) {
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c0 = (id)predicate;
        
        NSPredicateOperatorType op = c0.predicateOperatorType;
        if (op != NSEqualToPredicateOperatorType && op != NSNotEqualToPredicateOperatorType) {
            return NO;
        }
        
        BOOL open = NO;
        NSExpression *lhs = c0.leftExpression;
        NSExpression *rhs = c0.rightExpression;
        
        if (lhs.expressionType == NSKeyPathExpressionType
            && [lhs.keyPath isEqualToString:@"closed"]
            && rhs.expressionType == NSConstantValueExpressionType)
        {
            open = [rhs.constantValue boolValue];
            if (op == NSEqualToPredicateOperatorType) {
                open = !open;
            }
        } else if (rhs.expressionType == NSKeyPathExpressionType
                   && [rhs.keyPath isEqualToString:@"closed"]
                   && lhs.expressionType == NSConstantValueExpressionType) {
            open = [lhs.constantValue boolValue];
            if (op == NSEqualToPredicateOperatorType) {
                open = !open;
            }
        } else if (lhs.expressionType == NSKeyPathExpressionType
                   && [lhs.keyPath isEqualToString:@"state"]
                   && rhs.expressionType == NSConstantValueExpressionType) {
            open = [rhs.constantValue isEqualToString:@"open"];
            if (op == NSNotEqualToPredicateOperatorType) {
                open = !open;
            }
        } else if (rhs.expressionType == NSKeyPathExpressionType
                   && [rhs.keyPath isEqualToString:@"state"]
                   && lhs.expressionType == NSConstantValueExpressionType) {
            open = [lhs.constantValue isEqualToString:@"open"];
            if (op == NSNotEqualToPredicateOperatorType) {
                open = !open;
            }
        } else {
            return NO;
        }
        
        *isOpenValue = open;
        return YES;
    }
    return NO;
}

+ (NSPredicate *)predicateWithoutState:(NSPredicate *)p; // strip out any state or closed comparison predicates
{
    return [p predicateByRewriting:^NSPredicate *(NSPredicate *original) {
        BOOL ignored;
        if (isStatePredicate(original, &ignored)) {
            return [NSPredicate predicateWithValue:YES];
        }
        
        return original;
    }];
}

+ (NSPredicate *)timeSeriesPredicateWithPredicate:(NSPredicate *)queryPredicate startDate:(NSDate *)startDate endDate:(NSDate *)endDate open:(NSNumber *__autoreleasing*)outOpen
{
    __block NSInteger openCount = 0;
    __block NSInteger closedCount = 0;
    
    NSPredicate *predicate = [queryPredicate predicateByRewriting:^NSPredicate *(NSPredicate *original) {
        
        BOOL isOpenState = NO;
        if (isStatePredicate(original, &isOpenState)) {
            if (isOpenState) openCount++;
            else closedCount++;
            return [NSPredicate predicateWithValue:YES];
        }
        
        return original;
    }];
    
    NSNumber *open = nil;
    if (openCount > 0 && closedCount == 0) {
        open = @YES;
    } else if (openCount == 0 && closedCount > 0) {
        open = @NO;
    } // else querying all issues
    
    if (outOpen) {
        *outOpen = open;
    }
    
    return [predicate and:[self predicateFromStartDate:startDate untilEndDate:endDate open:open]];
}

+ (NSPredicate *)timeSeriesPredicateWithPredicate:(NSPredicate *)queryPredicate startDate:(NSDate *)startDate endDate:(NSDate *)endDate
{
    return [self timeSeriesPredicateWithPredicate:queryPredicate startDate:startDate endDate:endDate open:NULL];
}

- (void)_fastSelectRecordsFrom:(NSArray<Issue *> *)records {
    NSPredicate *p = [TimeSeries _fastPredicateFromStartDate:self.startDate untilEndDate:self.endDate open:_open];
    
    self.records = [records filteredArrayUsingPredicate:p];
}

- (void)selectRecordsFrom:(NSArray<Issue *> *)records {
    NSPredicate *p = [TimeSeries timeSeriesPredicateWithPredicate:self.predicate startDate:self.startDate endDate:self.endDate];
    
    self.records = [records filteredArrayUsingPredicate:p];
}

- (void)generateIntervalsWithCalendarUnit:(NSCalendarUnit)unit {
    NSMutableArray *intervals = [NSMutableArray new];
    TimeSeries *current = [TimeSeries new];
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    current.predicate = self.predicate;
    current.open = _open;
    current.startDate = self.startDate;
    current.endDate = [calendar dateByAddingUnit:unit value:1 toDate:self.startDate options:0];
    
    do {
        [intervals addObject:current];
        
        TimeSeries *next = [TimeSeries new];
        next.predicate = current.predicate;
        next.open = current.open;
        next.startDate = [calendar dateByAddingUnit:unit value:1 toDate:current.startDate options:0];
        next.endDate = [calendar dateByAddingUnit:unit value:1 toDate:current.endDate options:0];
        current = next;
    } while ([current.startDate compare:self.endDate] != NSOrderedDescending);
    
    // in parallel, make each interval select its records
    dispatch_apply(intervals.count, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(size_t i) {
        [intervals[i] _fastSelectRecordsFrom:self.records];
    });
    
    self.intervals = intervals;
}

@end

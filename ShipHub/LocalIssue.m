//
//  LocalIssue.m
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "LocalIssue.h"
#import "LocalMilestone.h"
#import "LocalRepo.h"
#import "LocalAccount.h"

#import "IssueIdentifier.h"

@implementation LocalIssue

- (void)willSave {
    NSNumber *closed = self.closed;
    NSNumber *newClosed = [[self state] isEqualToString:@"closed"] ? @YES : @NO;
    
    if (![closed isEqual:newClosed]) {
        self.closed = newClosed;
    }
    
    [super willSave];
}

- (void)setShipLocalUpdatedAtIfNewer:(NSDate *)value {
    if (!value) return;
    NSDate *current = self.shipLocalUpdatedAt;
    if (current != nil && [current compare:value] == NSOrderedDescending) {
        // if we already have a date and it's newer than value, skip changing
        return;
    }
    self.shipLocalUpdatedAt = value;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"pullRequest"]) {
        if ([value isKindOfClass:[NSDictionary class]]) {
            value = @YES;
        }
    } else if ([key isEqualToString:@"shipLocalUpdatedAt"]) {
        if (!value) return;
        NSDate *current = [self valueForKey:key];
        if (current != nil && [current compare:value] == NSOrderedDescending) {
            // if we already have a date and it's newer than value, skip changing
            return;
        }
    }
    [super setValue:value forKey:key];
}

- (NSString *)fullIdentifier {
    if (!self.repository.fullName || !self.number) {
        return nil;
    }
    return [NSString stringWithFormat:@"%@#%lld", self.repository.fullName, self.number.longLongValue];
}

@end

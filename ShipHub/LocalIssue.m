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
    if (self.fullIdentifier == nil && self.repository && self.number) {
        self.fullIdentifier = [NSString issueIdentifierWithOwner:self.repository.owner.login repo:self.repository.name number:self.number];
    } else {
        NSAssert(self.fullIdentifier != nil, @"Wha?");
    }
    
    NSNumber *closed = self.closed;
    NSNumber *newClosed = [[self state] isEqualToString:@"closed"] ? @YES : @NO;
    
    if (![closed isEqual:newClosed]) {
        self.closed = newClosed;
    }
    
    [super willSave];
}

@end

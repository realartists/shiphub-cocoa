//
//  Milestone.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Milestone.h"

#import "Extras.h"

#if TARGET_SHIP
#import "LocalMilestone.h"
#import "LocalRepo.h"
#endif

@implementation Milestone

#if TARGET_SHIP
- (instancetype)initWithLocalItem:(id)localItem {
    LocalMilestone *lm = localItem;
    if (self = [super initWithLocalItem:lm]) {
        _number = lm.number;
        _title = lm.title;
        _createdAt = lm.createdAt;
        _closedAt = lm.closedAt;
        _dueOn = lm.dueOn;
        _milestoneDescription = lm.milestoneDescription;
        _updatedAt = lm.updatedAt;
        _state = lm.state;
        _closed = [_state isEqualToString:@"closed"];
        _hidden = lm.hidden != nil;
        _repoFullName = lm.repository.fullName;
    }
    return self;
}
#endif

- (instancetype)initWithDictionary:(NSDictionary *)d {
    if (self = [super initWithDictionary:d]) {
        _number = d[@"number"];
        _title = d[@"title"];
        _createdAt = [NSDate dateWithJSONString:d[@"created_at"]];
        _closedAt = [NSDate dateWithJSONString:d[@"closed_at"]];
        _dueOn = [NSDate dateWithJSONString:d[@"due_on"]];
        _milestoneDescription = d[@"description"];
        _state = d[@"state"];
        _closed = [_state isEqualToString:@"closed"];
    }
    return self;
}

@end

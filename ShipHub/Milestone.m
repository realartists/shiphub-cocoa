//
//  Milestone.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Milestone.h"

#import "LocalMilestone.h"
#import "LocalRepo.h"

@implementation Milestone

- (instancetype)initWithLocalItem:(id)localItem {
    LocalMilestone *lm = localItem;
    if (self = [super initWithLocalItem:lm]) {
        _number = lm.number;
        _title = lm.title;
        _createdAt = lm.createdAt;
        _closedAt = lm.closedAt;
        _dueOn = lm.dueOn;
        _milestoneDescription = lm.milestoneDescription;
        _title = lm.title;
        _updatedAt = lm.updatedAt;
        _state = lm.state;
        _closed = [_state isEqualToString:@"closed"];
        _hidden = lm.hidden != nil;
        _repoFullName = lm.repository.fullName;
    }
    return self;
}

@end

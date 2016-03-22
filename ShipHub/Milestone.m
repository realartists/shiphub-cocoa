//
//  Milestone.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Milestone.h"

#import "LocalMilestone.h"

@implementation Milestone

- (instancetype)initWithLocalItem:(id)localItem {
    LocalMilestone *lm = localItem;
    if (self = [super initWithLocalItem:lm]) {
        _title = lm.title;
        _closedAt = lm.closedAt;
        _dueOn = lm.dueOn;
        _milestoneDescription = lm.milestoneDescription;
        _title = lm.title;
        _updatedAt = lm.updatedAt;
    }
    return self;
}

@end

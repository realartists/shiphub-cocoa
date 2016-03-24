//
//  Issue.m
//  ShipHub
//
//  Created by James Howard on 3/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Issue.h"

#import "Extras.h"

#import "LocalIssue.h"
#import "LocalRepo.h"
#import "LocalUser.h"
#import "LocalMilestone.h"
#import "LocalLabel.h"

#import "Repo.h"
#import "User.h"
#import "Milestone.h"
#import "Label.h"

#import "MetadataStore.h"

@implementation Issue

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms
{
    if (self = [super init]) {
        _number = li.number;
        _fullIdentifier = li.fullIdentifier;
        _body = li.body;
        _title = li.title;
        _closed = [li.closed boolValue];
        _createdAt = li.createdAt;
        _updatedAt = li.updatedAt;
        _locked = [li.locked boolValue];
        _assignee = [ms userWithIdentifier:li.assignee.identifier];
        _closedBy = [ms userWithIdentifier:li.closedBy.identifier];
        _labels = [[li.labels allObjects] arrayByMappingObjects:^id(id obj) {
            return [[Label alloc] initWithLocalItem:obj];
        }];
        _milestone = [ms milestoneWithIdentifier:li.milestone.identifier];
        _repository = [ms repoWithIdentifier:li.repository.identifier];
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> %@ %@", NSStringFromClass([self class]), self, self.fullIdentifier, self.title];
}

@end

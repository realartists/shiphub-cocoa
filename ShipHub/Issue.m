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
#import "LocalPriority.h"
#import "LocalNotification.h"

#import "Repo.h"
#import "User.h"
#import "Milestone.h"
#import "Label.h"
#import "IssueEvent.h"
#import "IssueComment.h"
#import "Reaction.h"

#import "MetadataStore.h"

@implementation Issue

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms {
    return [self initWithLocalIssue:li metadataStore:ms options:nil];
}

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms options:(NSDictionary *)options
{
    if (self = [super init]) {
        _number = li.number;
        _fullIdentifier = li.fullIdentifier;
        _identifier = li.identifier;
        _body = li.body;
        _title = li.title;
        _closed = [li.closed boolValue];
        _createdAt = li.createdAt;
        _updatedAt = li.updatedAt;
        _closedAt = li.closedAt;
        _locked = [li.locked boolValue];
        _assignees = [[li.assignees array] arrayByMappingObjects:^id(LocalUser *obj) {
            return [ms userWithIdentifier:obj.identifier];
        }];
        _originator = [ms userWithIdentifier:li.originator.identifier];
        _closedBy = [ms userWithIdentifier:li.closedBy.identifier];
        _labels = [[[li.labels allObjects] arrayByMappingObjects:^id(id obj) {
            return [[Label alloc] initWithLocalItem:obj];
        }] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        _milestone = [ms milestoneWithIdentifier:li.milestone.identifier];
        _repository = [ms repoWithIdentifier:li.repository.identifier];
        
        _unread = [li.notification.unread boolValue];
        
        BOOL includeECs = [options[IssueOptionIncludeEventsAndComments] boolValue];
        if (includeECs) {
            NSSortDescriptor *createSort = [NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES];
            
            NSArray<LocalEvent *> *localEvents = [[li.events allObjects] sortedArrayUsingDescriptors:@[createSort]];
            NSArray<LocalComment *> *localComments = [[li.comments allObjects] sortedArrayUsingDescriptors:@[createSort]];
            
            _events = [localEvents arrayByMappingObjects:^id(LocalEvent *obj) {
                return [[IssueEvent alloc] initWithLocalEvent:obj metadataStore:ms];
            }];
            
            _comments = [localComments arrayByMappingObjects:^id(LocalComment *obj) {
                return [[IssueComment alloc] initWithLocalComment:obj metadataStore:ms];
            }];
            _commentsCount = _comments.count;
            
            _reactions = [[li.reactions allObjects] arrayByMappingObjects:^id(id obj) {
                return [[Reaction alloc] initWithLocalReaction:obj metadataStore:ms];
            }];
        } else {
            _commentsCount = [li.comments count];
            _reactionsCount = [li.reactions count];
        }
        
        BOOL includePriority = [options[IssueOptionIncludeUpNextPriority] boolValue];
        if (includePriority) {
            LocalPriority *upNext = [[li.upNext filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"user.identifier = %@", [[User me] identifier]]] anyObject];
            _upNextPriority = upNext.priority;
        }
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> %@ %@\nlabels:%@\ncomments:%@\nevents:%@\nunread: %d", NSStringFromClass([self class]), self, self.fullIdentifier, self.title, self.labels, self.comments, self.events, self.unread];
}

- (User *)assignee {
    return [_assignees firstObject];
}

- (NSString *)state {
    return _closed ? @"closed" : @"open";
}

- (Issue *)clone {
    Issue *i = [Issue new];
    i->_body = [self.body copy];
    i->_title = [self.title copy];
    i->_assignees = [self.assignees copy];
    i->_labels = [self.labels copy];
    i->_milestone = self.milestone;
    i->_repository = self.repository;
    
    return i;
}

@end

NSString const* IssueOptionIncludeEventsAndComments = @"IssueOptionIncludeEventsAndComments";
NSString const* IssueOptionIncludeUpNextPriority = @"IssueOptionIncludeUpNextPriority";

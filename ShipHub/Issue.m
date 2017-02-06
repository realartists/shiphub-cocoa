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
#import "LocalAccount.h"
#import "LocalMilestone.h"
#import "LocalLabel.h"
#import "LocalPriority.h"
#import "LocalNotification.h"

#import "Repo.h"
#import "Account.h"
#import "Milestone.h"
#import "Label.h"
#import "IssueEvent.h"
#import "IssueComment.h"
#import "IssueNotification.h"
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
        _assignees = [[li.assignees array] arrayByMappingObjects:^id(LocalAccount *obj) {
            return [ms accountWithIdentifier:obj.identifier];
        }];
        _originator = [ms accountWithIdentifier:li.originator.identifier];
        _closedBy = [ms accountWithIdentifier:li.closedBy.identifier];
        NSArray *loadedLabels = [[li.labels allObjects] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name != nil && color != nil"]];
        _labels = [[loadedLabels arrayByMappingObjects:^id(id obj) {
            return [[Label alloc] initWithLocalItem:obj];
        }] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        _milestone = [ms milestoneWithIdentifier:li.milestone.identifier];
        _repository = [ms repoWithIdentifier:li.repository.identifier];
        _reactionSummary = (id)(li.shipReactionSummary);
        
        for (NSNumber *v in _reactionSummary.allValues) {
            _reactionsCount += v.integerValue;
        }
        
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
            
            _reactions = [[li.reactions allObjects] arrayByMappingObjects:^id(id obj) {
                return [[Reaction alloc] initWithLocalReaction:obj metadataStore:ms];
            }];
        }
        
        BOOL includePriority = [options[IssueOptionIncludeUpNextPriority] boolValue];
        if (includePriority) {
            LocalPriority *upNext = [[li.upNext filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"user.identifier = %@", [[Account me] identifier]]] anyObject];
            _upNextPriority = upNext.priority;
        }
        
        BOOL includeNotification = [options[IssueOptionIncludeNotification] boolValue];
        if (includeNotification) {
            LocalNotification *ln = li.notification;
            _notification = [[IssueNotification alloc] initWithLocalNotification:ln];
        }
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> %@ %@\nlabels:%@\ncomments:%@\nevents:%@\nunread: %d", NSStringFromClass([self class]), self, self.fullIdentifier, self.title, self.labels, self.comments, self.events, self.unread];
}

- (Account *)assignee {
    return [_assignees firstObject];
}

- (NSString *)state {
    return _closed ? @"closed" : @"open";
}

- (Issue *)clone {
    Issue *i = [Issue new];
    i->_originator = [Account me];
    i->_body = [self.body copy];
    i->_title = [self.title copy];
    i->_assignees = [self.assignees copy];
    i->_labels = [self.labels copy];
    i->_milestone = self.milestone;
    i->_repository = self.repository;
    
    return i;
}

- (instancetype)initWithTitle:(NSString *)title repo:(Repo *)repo milestone:(Milestone *)mile assignees:(NSArray<Account *> *)assignees labels:(NSArray<Label *> *)labels body:(NSString *)body
{
    if (self = [super init]) {
        _originator = [Account me];
        _labels = [labels copy];
        _body = [body copy];
        _title = [title copy] ?: @"";
        _assignees = [assignees copy];
        _labels = [labels copy];
        _milestone = mile;
        _repository = repo;
    }
    return self;
}

- (NSComparisonResult)labelsCompare:(Issue *)other {
    NSArray *l1 = _labels;
    NSArray *l2 = other.labels;
    
    NSUInteger c1 = l1.count;
    NSUInteger c2 = l2.count;
    
    for (NSUInteger i = 0; i < c1 && i < c2; i++) {
        Label *ll1 = l1[i];
        Label *ll2 = l2[i];
        
        NSString *n1 = ll1.name;
        NSString *n2 = ll2.name;
        
        NSComparisonResult cr = [n1 localizedStandardCompare:n2];
        if (cr != NSOrderedSame) {
            return cr;
        }
    }
    
    if (c1 < c2) {
        return NSOrderedAscending;
    } else if (c1 > c2) {
        return NSOrderedDescending;
    } else {
        return NSOrderedSame;
    }
}

@end

NSString const* IssueOptionIncludeEventsAndComments = @"IssueOptionIncludeEventsAndComments";
NSString const* IssueOptionIncludeUpNextPriority = @"IssueOptionIncludeUpNextPriority";
NSString const* IssueOptionIncludeNotification = @"IssueOptionIncludeNotification";

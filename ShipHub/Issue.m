//
//  Issue.m
//  ShipHub
//
//  Created by James Howard on 3/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueInternal.h"

#import "Extras.h"

#import "LocalIssue.h"
#import "LocalRepo.h"
#import "LocalAccount.h"
#import "LocalMilestone.h"
#import "LocalLabel.h"
#import "LocalPriority.h"
#import "LocalNotification.h"
#import "LocalPRReview.h"
#import "LocalPRComment.h"
#import "LocalPullRequest.h"

#import "Repo.h"
#import "Account.h"
#import "Milestone.h"
#import "Label.h"
#import "IssueEvent.h"
#import "IssueComment.h"
#import "IssueIdentifier.h"
#import "IssueNotification.h"
#import "Reaction.h"
#import "PRReview.h"
#import "PRComment.h"

#import "MetadataStore.h"

@interface Issue ()

@property (readwrite) NSString *fullIdentifier; // e.g. realartists/shiphub-server#11
@property (readwrite) NSNumber *identifier;
@property (readwrite) NSNumber *number;
@property (readwrite) NSString *body;
@property (readwrite) NSString *title;
@property (readwrite) BOOL closed;
@property (readwrite) NSDate *createdAt;
@property (readwrite) NSDate *updatedAt;
@property (readwrite) NSDate *closedAt;
@property (readwrite) BOOL locked;
@property (readwrite) NSArray<Account *> *assignees;
@property (readwrite) Account *originator;
@property (readwrite) Account *closedBy;
@property (readwrite) NSArray<Label *> *labels;
@property (readwrite) Milestone * milestone;
@property (readwrite) Repo * repository;
@property (readwrite) NSDictionary<NSString *, NSNumber *> *reactionSummary;
@property (readwrite) NSInteger reactionsCount; // computed from reactionSummary, not the array of reactions
@property (readwrite) BOOL unread;

@property (readwrite) BOOL pullRequest;
@property (readwrite) NSNumber *pullRequestIdentifier;
@property (readwrite) NSNumber *maintainerCanModify;
@property (readwrite) NSNumber *mergeable;
@property (readwrite) NSString *mergeableState;
@property (readwrite) NSString *mergeCommitSha;
@property (readwrite) NSNumber *merged;
@property (readwrite) NSNumber *additions;
@property (readwrite) NSNumber *deletions;
@property (readwrite) NSNumber *changedFiles;
@property (readwrite) NSNumber *commits;
@property (readwrite) NSNumber *rebaseable;
@property (readwrite) NSDate *mergedAt;
@property (readwrite) Account *mergedBy;

@property (readwrite) NSDictionary *base;
@property (readwrite) NSDictionary *head;
@property (readwrite) NSDictionary *baseBranchProtection;

// events and comments are conditionally populated.
// if they're just nonexistent, then they will be empty arrays.
// if they're not populated at all, then they will be nil.
@property (readwrite) NSArray<IssueEvent *> *events;
@property (readwrite) NSArray<IssueComment *> *comments;
@property (readwrite) NSArray<Reaction*> *reactions;

@property (readwrite) NSArray<PRReview *> *reviews; // comments that are associated with a review
@property (readwrite) NSArray<PRComment *> *prComments; // comments that are not associated with a review

@property (readwrite) NSArray<Account *> *requestedReviewers; // conditionally populated

@property (readwrite) NSArray<CommitStatus *> *commitStatuses; // conditionally populated
@property (readwrite) NSArray<CommitComment *> *commitComments; // conditionally populated

// Up Next priority is conditionally populated.
@property (readwrite) NSNumber *upNextPriority;

// Notification is conditionally populated.
@property (readwrite) IssueNotification *notification;

@end

@implementation Issue

#if TARGET_SHIP
- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms {
    return [self initWithLocalIssue:li metadataStore:ms options:nil];
}

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms options:(NSDictionary *)options
{
    if (self = [super init]) {
        _number = li.number;
        _identifier = li.identifier;
        _body = li.body;
        _title = li.title;
        _closed = [li.closed boolValue];
        _createdAt = li.createdAt;
        _updatedAt = li.updatedAt;
        _closedAt = li.closedAt;
        _locked = [li.locked boolValue];
        static NSArray *assigneesSort = nil;
        static NSArray *labelsSort = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            assigneesSort = @[[NSSortDescriptor sortDescriptorWithKey:@"login" ascending:YES selector:@selector(localizedStandardCompare:)]];
            labelsSort = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)]];
        });
        
        NSMutableArray *assignees = [NSMutableArray arrayWithCapacity:li.assignees.count];
        for (LocalAccount *la in li.assignees) {
            Account *a = [ms objectWithManagedObject:la];
            if (a) {
                [assignees addObject:a];
            }
        }
        [assignees sortUsingDescriptors:assigneesSort];
        _assignees = assignees;
        
        _originator = [ms objectWithManagedObject:li.originator];
        _closedBy = [ms objectWithManagedObject:li.closedBy];
        
        NSMutableArray *labels = [NSMutableArray arrayWithCapacity:li.labels.count];
        for (LocalLabel *ll in li.labels) {
            Label *l = [ms objectWithManagedObject:ll];
            if (l) {
                [labels addObject:l];
            }
        }
        [labels sortUsingDescriptors:labelsSort];
        _labels = labels;
        
        _milestone = [ms objectWithManagedObject:li.milestone];
        _repository = [ms objectWithManagedObject:li.repository];
        _reactionSummary = (id)(li.shipReactionSummary);
        
        for (NSNumber *v in _reactionSummary.allValues) {
            _reactionsCount += v.integerValue;
        }
        
        _unread = [li.notification.unread boolValue];
        
        _fullIdentifier = [NSString issueIdentifierWithOwner:_repository.owner.login repo:_repository.name number:li.number];
        
        _pullRequest = [li.pullRequest boolValue];
        if (_pullRequest) {
            LocalPullRequest *lpr = li.pr;
            _pullRequestIdentifier = lpr.identifier;
            _maintainerCanModify = lpr.maintainerCanModify;
            _mergeable = lpr.mergeable;
            _mergeableState = lpr.mergeableState;
            _mergeCommitSha = lpr.mergeCommitSha;
            _merged = lpr.merged;
            _mergedAt = lpr.mergedAt;
            _mergedBy = [ms objectWithManagedObject:lpr.mergedBy];
            _additions = lpr.additions;
            _deletions = lpr.deletions;
            _changedFiles = lpr.changedFiles;
            _commits = lpr.commits;
            _rebaseable = lpr.rebaseable;
            _base = (id)(lpr.base);
            _head = (id)(lpr.head);
        }
        
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
            
            if (_pullRequest) {
                NSMutableSet *singleComments = [NSMutableSet setWithSet:li.prComments];
                NSMutableArray *reviews = [NSMutableArray arrayWithCapacity:li.reviews.count];
                for (LocalPRReview *lr in li.reviews) {
                    [singleComments minusSet:lr.comments];
                    PRReview *r = [[PRReview alloc] initWithLocalReview:lr metadataStore:ms];
                    [reviews addObject:r];
                }
                
                NSArray *prComments = [[singleComments allObjects] arrayByMappingObjects:^id(id obj) {
                    return [[PRComment alloc] initWithLocalPRComment:obj metadataStore:ms];
                }];
                
                _prComments = [prComments sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]];
                
                [reviews sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"submittedAt" ascending:YES]]];
                _reviews = reviews;
            }
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
        
        BOOL includeReviewRequests = [options[IssueOptionIncludeRequestedReviewers] boolValue];
        if (includeReviewRequests) {
            NSMutableArray *requests = [NSMutableArray arrayWithCapacity:li.pr.requestedReviewers.count];
            for (LocalAccount *la in li.pr.requestedReviewers) {
                Account *a = [ms objectWithManagedObject:la];
                if (a) {
                    [requests addObject:a];
                }
            }
            [requests sortUsingDescriptors:assigneesSort];
            _requestedReviewers = requests;
        }
    }
    return self;
}
#endif

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

- (instancetype)initPRWithTitle:(NSString *)title repo:(Repo *)repo body:(NSString *)body baseInfo:(NSDictionary *)baseInfo headInfo:(NSDictionary *)headInfo
{
    if (self = [super init]) {
        _originator = [Account me];
        _labels = @[];
        _assignees = @[];
        if ([repo.pullRequestTemplate trim].length) {
            _body = [repo.pullRequestTemplate copy];
        } else {
            _body = [body copy];
        }
        _title = [title copy] ?: @"";
        _repository = repo;
        _pullRequest = YES;
        _base = baseInfo;
        _head = headInfo;
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
NSString const* IssueOptionIncludeRequestedReviewers = @"IssueOptionIncludeRequestedReviewers";
NSString const* IssueOptionIncludeCommitStatuses = @"IssueOptionIncludeCommitStatuses";

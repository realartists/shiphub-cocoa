//
//  IssueInternal.h
//  ShipHub
//
//  Created by James Howard on 5/19/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "Issue.h"

@interface Issue (Internal)

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

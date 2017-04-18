//
//  Issue.h
//  ShipHub
//
//  Created by James Howard on 3/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Repo;
@class Account;
@class Milestone;
@class Label;
@class IssueEvent;
@class IssueComment;
@class IssueNotification;
@class Reaction;
@class PRReview;
@class PRComment;

@class LocalIssue;
@class MetadataStore;

@interface Issue : NSObject

@property (readonly) NSString *fullIdentifier; // e.g. realartists/shiphub-server#11
@property (readonly) NSNumber *identifier;
@property (readonly) NSNumber *number;
@property (readonly) NSString *body;
@property (readonly) NSString *title;
@property (readonly) BOOL closed;
@property (readonly) NSString *state;
@property (readonly) NSDate *createdAt;
@property (readonly) NSDate *updatedAt;
@property (readonly) NSDate *closedAt;
@property (readonly) BOOL locked;
@property (readonly) Account *assignee;
@property (readonly) NSArray<Account *> *assignees;
@property (readonly) Account *originator;
@property (readonly) Account *closedBy;
@property (readonly) NSArray<Label*> *labels;
@property (readonly) Milestone *milestone;
@property (readonly) Repo *repository;
@property (readonly) NSDictionary<NSString *, NSNumber *> *reactionSummary;
@property (readonly) NSInteger reactionsCount; // computed from reactionSummary, not the array of reactions
@property (readonly) BOOL unread;

@property (readonly) BOOL pullRequest;
@property (readonly) NSNumber *pullRequestIdentifier;
@property (readonly) NSNumber *maintainerCanModify;
@property (readonly) NSNumber *mergeable;
@property (readonly) NSString *mergeCommitSha;
@property (readonly) NSNumber *merged;
@property (readonly) NSDate *mergedAt;
@property (readonly) Account *mergedBy;

@property (readonly) NSDictionary *base;
@property (readonly) NSDictionary *head;

// events and comments are conditionally populated.
// if they're just nonexistent, then they will be empty arrays.
// if they're not populated at all, then they will be nil.
@property (readonly) NSArray<IssueEvent *> *events;
@property (readonly) NSArray<IssueComment *> *comments;
@property (readonly) NSArray<Reaction*> *reactions;

@property (readonly) NSArray<PRReview *> *reviews; // comments that are associated with a review
@property (readonly) NSArray<PRComment *> *prComments; // comments that are not associated with a review

@property (readonly) NSArray<Account *> *requestedReviewers; // conditionally populated

// Up Next priority is conditionally populated.
@property (readonly) NSNumber *upNextPriority;

// Notification is conditionally populated.
@property (readonly) IssueNotification *notification;

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms;

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms options:(NSDictionary *)options;

- (instancetype)initWithTitle:(NSString *)title repo:(Repo *)repo milestone:(Milestone *)mile assignees:(NSArray<Account *> *)assignees labels:(NSArray<Label *> *)labels body:(NSString *)body;

- (instancetype)initPRWithTitle:(NSString *)title repo:(Repo *)repo body:(NSString *)body baseInfo:(NSDictionary *)baseInfo headInfo:(NSDictionary *)headInfo;

- (Issue *)clone;

- (NSComparisonResult)labelsCompare:(Issue *)other;

@end

extern NSString const* IssueOptionIncludeEventsAndComments;
extern NSString const* IssueOptionIncludeUpNextPriority;
extern NSString const* IssueOptionIncludeNotification;
extern NSString const* IssueOptionIncludeRequestedReviewers;


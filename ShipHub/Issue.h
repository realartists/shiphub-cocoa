//
//  Issue.h
//  ShipHub
//
//  Created by James Howard on 3/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Repo;
@class User;
@class Milestone;
@class Label;
@class IssueEvent;
@class IssueComment;
@class IssueNotification;
@class Reaction;

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
@property (readonly) User *assignee;
@property (readonly) NSArray<User*> *assignees;
@property (readonly) User *originator;
@property (readonly) User *closedBy;
@property (readonly) NSArray<Label*> *labels;
@property (readonly) Milestone *milestone;
@property (readonly) Repo *repository;
@property (readonly) NSDictionary<NSString *, NSNumber *> *reactionSummary;
@property (readonly) NSInteger reactionsCount; // computed from reactionSummary, not the array of reactions
@property (readonly) BOOL unread;

// events and comments are conditionally populated.
// if they're just nonexistent, then they will be empty arrays.
// if they're not populated at all, then they will be nil.
@property (readonly) NSArray<IssueEvent *> *events;
@property (readonly) NSArray<IssueComment *> *comments;
@property (readonly) NSArray<Reaction*> *reactions;

// Up Next priority is conditionally populated.
@property (readonly) NSNumber *upNextPriority;

// Notification is conditionally populated.
@property (readonly) IssueNotification *notification;

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms;

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms options:(NSDictionary *)options;

- (Issue *)clone;

@end

extern NSString const* IssueOptionIncludeEventsAndComments;
extern NSString const* IssueOptionIncludeUpNextPriority;
extern NSString const* IssueOptionIncludeNotification;

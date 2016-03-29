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

@class LocalIssue;
@class MetadataStore;

@interface Issue : NSObject

@property (readonly) NSString *fullIdentifier; // e.g. realartists/shiphub-server#11
@property (readonly) NSNumber *identifier;
@property (readonly) NSNumber *number;
@property (readonly) NSString *body;
@property (readonly) NSString *title;
@property (readonly) BOOL closed;
@property (readonly) NSDate *createdAt;
@property (readonly) NSDate *updatedAt;
@property (readonly) BOOL locked;
@property (readonly) User *assignee;
@property (readonly) User *originator;
@property (readonly) User *closedBy;
@property (readonly) NSArray<Label*> *labels;
@property (readonly) Milestone *milestone;
@property (readonly) Repo *repository;

// events and comments are conditionally populated.
// if they're just nonexistent, then they will be empty arrays.
// if they're not populated at all, then they will be nil.
@property (readonly) NSArray<IssueEvent *> *events;
@property (readonly) NSArray<IssueComment *> *comments;

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms;

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms includeEventsAndComments:(BOOL)includeECs;

@end



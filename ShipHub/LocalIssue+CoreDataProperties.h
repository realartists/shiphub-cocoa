//
//  LocalIssue+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalIssue.h"

@class LocalRelationship;
@class LocalAccount;
@class LocalLabel;
@class LocalRepo;
@class LocalEvent;
@class LocalComment;
@class LocalPriority;
@class LocalNotification;
@class LocalReaction;
@class LocalPRComment;
@class LocalPRReview;
@class LocalPullRequest;

NS_ASSUME_NONNULL_BEGIN

@interface LocalIssue (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *body;
@property (nullable, nonatomic, retain) NSNumber *closed;
@property (nullable, nonatomic, retain) NSString *state;
@property (nullable, nonatomic, retain) NSNumber *pullRequest;
@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSNumber *locked;
@property (nullable, nonatomic, retain) NSNumber *number;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSDate *updatedAt;
@property (nullable, nonatomic, retain) NSDate *closedAt;
@property (nullable, nonatomic, retain) NSDate *shipLocalUpdatedAt;
@property (nullable, nonatomic, retain) id<NSCoding> shipReactionSummary;
@property (nullable, nonatomic, retain) NSOrderedSet<LocalAccount *> *assignees;
@property (nullable, nonatomic, retain) NSSet<LocalRelationship *> *childRelationships;
@property (nullable, nonatomic, retain) LocalAccount *closedBy;
@property (nullable, nonatomic, retain) NSSet<LocalLabel *> *labels;
@property (nullable, nonatomic, retain) LocalMilestone *milestone;
@property (nullable, nonatomic, retain) LocalAccount *originator;
@property (nullable, nonatomic, retain) NSSet<LocalRelationship *> *relationships;
@property (nullable, nonatomic, retain) LocalRepo *repository;
@property (nullable, nonatomic, retain) NSSet<LocalEvent *> *events;
@property (nullable, nonatomic, retain) NSSet<LocalComment *> *comments;
@property (nullable, nonatomic, retain) NSSet<LocalPriority *> *upNext;
@property (nullable, nonatomic, retain) LocalNotification *notification;
@property (nullable, nonatomic, retain) NSSet<LocalReaction *> *reactions;

@property (nullable, nonatomic, retain) NSSet<LocalPRReview *> *reviews;
@property (nullable, nonatomic, retain) NSSet<LocalPRComment *> *prComments;

@property (nullable, nonatomic, retain) LocalPullRequest *pr;

@end

@interface LocalIssue (CoreDataGeneratedAccessors)

- (void)addChildRelationshipsObject:(LocalRelationship *)value;
- (void)removeChildRelationshipsObject:(LocalRelationship *)value;
- (void)addChildRelationships:(NSSet<LocalRelationship *> *)values;
- (void)removeChildRelationships:(NSSet<LocalRelationship *> *)values;

- (void)addLabelsObject:(LocalLabel *)value;
- (void)removeLabelsObject:(LocalLabel *)value;
- (void)addLabels:(NSSet<LocalLabel *> *)values;
- (void)removeLabels:(NSSet<LocalLabel *> *)values;

- (void)addRelationshipsObject:(LocalRelationship *)value;
- (void)removeRelationshipsObject:(LocalRelationship *)value;
- (void)addRelationships:(NSSet<LocalRelationship *> *)values;
- (void)removeRelationships:(NSSet<LocalRelationship *> *)values;

- (void)addEventsObject:(LocalEvent *)value;
- (void)removeEventsObject:(LocalEvent *)value;
- (void)addEvents:(NSSet<LocalEvent *> *)values;
- (void)removeEvents:(NSSet<LocalEvent *> *)values;

- (void)addCommentsObject:(LocalComment *)value;
- (void)removeCommentsObject:(LocalComment *)value;
- (void)addComments:(NSSet<LocalComment *> *)values;
- (void)removeComments:(NSSet<LocalComment *> *)values;

- (void)addUpNextObject:(LocalPriority *)value;
- (void)removeUpNextObject:(LocalPriority *)value;
- (void)addUpNext:(NSSet<LocalPriority *> *)values;
- (void)removeUpNext:(NSSet<LocalPriority *> *)values;

- (void)addAssigneesObject:(LocalAccount *)value;
- (void)removeAssigneesObject:(LocalAccount *)value;
- (void)addAssignees:(NSOrderedSet<LocalAccount *> *)values;
- (void)removeAssignees:(NSOrderedSet<LocalAccount *> *)values;

- (void)addReactionObject:(LocalReaction *)value;
- (void)removeReactionObject:(LocalReaction *)value;
- (void)addReactions:(NSSet<LocalReaction *> *)values;
- (void)removeReactions:(NSSet<LocalReaction *> *)values;

- (void)addReviewsObject:(LocalPRReview *)value;
- (void)removeReviewsObject:(LocalPRReview *)value;
- (void)addReviews:(NSSet<LocalPRReview *> *)values;
- (void)removeReviews:(NSSet<LocalPRReview *> *)values;

- (void)addPrCommentsObject:(LocalPRComment *)value;
- (void)removePrCommentsObject:(LocalPRComment *)value;
- (void)addPrComments:(NSSet<LocalPRComment *> *)values;
- (void)removePrComments:(NSSet<LocalPRComment *> *)values;


@end

NS_ASSUME_NONNULL_END

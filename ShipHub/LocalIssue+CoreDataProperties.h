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
@class LocalUser;
@class LocalLabel;
@class LocalRepo;
@class LocalEvent;
@class LocalComment;
@class LocalUpNext;

NS_ASSUME_NONNULL_BEGIN

@interface LocalIssue (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *body;
@property (nullable, nonatomic, retain) NSNumber *closed;
@property (nullable, nonatomic, retain) NSString *state;
@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSNumber *locked;
@property (nullable, nonatomic, retain) NSNumber *number;
@property (nullable, nonatomic, retain) NSString *fullIdentifier;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSDate *updatedAt;
@property (nullable, nonatomic, retain) NSDate *closedAt;
@property (nullable, nonatomic, retain) LocalUser *assignee;
@property (nullable, nonatomic, retain) NSSet<LocalRelationship *> *childRelationships;
@property (nullable, nonatomic, retain) LocalUser *closedBy;
@property (nullable, nonatomic, retain) NSSet<LocalLabel *> *labels;
@property (nullable, nonatomic, retain) LocalMilestone *milestone;
@property (nullable, nonatomic, retain) LocalUser *originator;
@property (nullable, nonatomic, retain) NSSet<LocalRelationship *> *relationships;
@property (nullable, nonatomic, retain) LocalRepo *repository;
@property (nullable, nonatomic, retain) NSSet<LocalEvent *> *events;
@property (nullable, nonatomic, retain) NSSet<LocalComment *> *comments;
@property (nullable, nonatomic, retain) NSSet<LocalUpNext *> *upNext;

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

- (void)addUpNextObject:(LocalUpNext *)value;
- (void)removeUpNextObject:(LocalUpNext *)value;
- (void)addUpNext:(NSSet<LocalUpNext *> *)values;
- (void)removeUpNext:(NSSet<LocalUpNext *> *)values;

@end

NS_ASSUME_NONNULL_END

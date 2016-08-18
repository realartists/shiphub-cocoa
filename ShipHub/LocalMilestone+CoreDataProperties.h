//
//  LocalMilestone+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalMilestone.h"

@class LocalIssue;
@class LocalRepo;
@class LocalHidden;

NS_ASSUME_NONNULL_BEGIN

@interface LocalMilestone (CoreDataProperties)

@property (nullable, nonatomic, retain) NSDate *closedAt;
@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) NSDate *dueOn;
@property (nullable, nonatomic, retain) NSNumber *number;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSString *milestoneDescription;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSDate *updatedAt;
@property (nullable, nonatomic, retain) NSString *state;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *issues;
@property (nullable, nonatomic, retain) LocalRepo *repository;
@property (nullable, nonatomic, retain) LocalHidden *hidden;

@end

@interface LocalMilestone (CoreDataGeneratedAccessors)

- (void)addIssuesObject:(LocalIssue *)value;
- (void)removeIssuesObject:(LocalIssue *)value;
- (void)addIssues:(NSSet<LocalIssue *> *)values;
- (void)removeIssues:(NSSet<LocalIssue *> *)values;

@end

NS_ASSUME_NONNULL_END

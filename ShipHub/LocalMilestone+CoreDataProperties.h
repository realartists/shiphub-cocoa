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

@class LocalEvent, LocalIssue;

NS_ASSUME_NONNULL_BEGIN

@interface LocalMilestone (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *closed;
@property (nullable, nonatomic, retain) NSDate *closedDate;
@property (nullable, nonatomic, retain) NSDate *creationDate;
@property (nullable, nonatomic, retain) NSDate *dueDate;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSString *milestoneDescription;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSDate *updatedDate;
@property (nullable, nonatomic, retain) NSSet<LocalEvent *> *events;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *issues;
@property (nullable, nonatomic, retain) NSManagedObject *repo;

@end

@interface LocalMilestone (CoreDataGeneratedAccessors)

- (void)addEventsObject:(LocalEvent *)value;
- (void)removeEventsObject:(LocalEvent *)value;
- (void)addEvents:(NSSet<LocalEvent *> *)values;
- (void)removeEvents:(NSSet<LocalEvent *> *)values;

- (void)addIssuesObject:(LocalIssue *)value;
- (void)removeIssuesObject:(LocalIssue *)value;
- (void)addIssues:(NSSet<LocalIssue *> *)values;
- (void)removeIssues:(NSSet<LocalIssue *> *)values;

@end

NS_ASSUME_NONNULL_END

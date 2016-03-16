//
//  LocalLabel+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalLabel.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalLabel (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *color;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSSet<LocalEvent *> *events;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *issues;
@property (nullable, nonatomic, retain) LocalRepo *repo;

@end

@interface LocalLabel (CoreDataGeneratedAccessors)

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

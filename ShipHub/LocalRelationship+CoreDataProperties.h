//
//  LocalRelationship+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalRelationship.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalRelationship (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *type;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *child;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *parent;

@end

@interface LocalRelationship (CoreDataGeneratedAccessors)

- (void)addChildObject:(LocalIssue *)value;
- (void)removeChildObject:(LocalIssue *)value;
- (void)addChild:(NSSet<LocalIssue *> *)values;
- (void)removeChild:(NSSet<LocalIssue *> *)values;

- (void)addParentObject:(LocalIssue *)value;
- (void)removeParentObject:(LocalIssue *)value;
- (void)addParent:(NSSet<LocalIssue *> *)values;
- (void)removeParent:(NSSet<LocalIssue *> *)values;

@end

NS_ASSUME_NONNULL_END

//
//  LocalEvent+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalEvent.h"

@class LocalUser;
@class LocalLabel;

NS_ASSUME_NONNULL_BEGIN

@interface LocalEvent (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *commitId;
@property (nullable, nonatomic, retain) NSString *commitURL;
@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) NSString *event;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) LocalUser *actor;
@property (nullable, nonatomic, retain) LocalUser *assignee;
@property (nullable, nonatomic, retain) NSSet<LocalLabel *> *labels;
@property (nullable, nonatomic, retain) LocalMilestone *milestone;

@end

@interface LocalEvent (CoreDataGeneratedAccessors)

- (void)addLabelsObject:(LocalLabel *)value;
- (void)removeLabelsObject:(LocalLabel *)value;
- (void)addLabels:(NSSet<LocalLabel *> *)values;
- (void)removeLabels:(NSSet<LocalLabel *> *)values;

@end

NS_ASSUME_NONNULL_END

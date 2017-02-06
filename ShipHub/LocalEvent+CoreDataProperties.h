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

@class LocalAccount;
@class LocalLabel;
@class LocalIssue;

NS_ASSUME_NONNULL_BEGIN

@interface LocalEvent (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *commitId;
@property (nullable, nonatomic, retain) NSString *commitURL;
@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) NSString *event;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSData *rawJSON;
@property (nullable, nonatomic, retain) LocalAccount *actor;
@property (nullable, nonatomic, retain) LocalAccount *assignee;
@property (nullable, nonatomic, retain) LocalIssue *issue;

@end

@interface LocalEvent (CoreDataGeneratedAccessors)

@end

NS_ASSUME_NONNULL_END

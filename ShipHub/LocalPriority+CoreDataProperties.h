//
//  LocalPriority+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 6/28/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalPriority.h"

@class LocalAccount;

NS_ASSUME_NONNULL_BEGIN

@interface LocalPriority (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *priority;
@property (nullable, nonatomic, retain) LocalAccount *user;
@property (nullable, nonatomic, retain) LocalIssue *issue;

@end

NS_ASSUME_NONNULL_END

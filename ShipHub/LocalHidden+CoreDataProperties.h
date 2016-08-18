//
//  LocalHidden+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 8/18/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalHidden.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalHidden (CoreDataProperties)

@property (nullable, nonatomic, retain) LocalMilestone *milestone;
@property (nullable, nonatomic, retain) LocalRepo *repository;

@end

NS_ASSUME_NONNULL_END

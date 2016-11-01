//
//  LocalProject+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalProject.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalProject (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSNumber *number;
@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) NSDate *updatedAt;
@property (nullable, nonatomic, retain) NSString *body;
@property (nullable, nonatomic, retain) LocalRepo *repository;
@property (nullable, nonatomic, retain) LocalUser *creator;
@property (nullable, nonatomic, retain) LocalOrg *organization;

@end

NS_ASSUME_NONNULL_END

//
//  LocalProject+CoreDataProperties.m
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalProject+CoreDataProperties.h"

@implementation LocalProject (CoreDataProperties)

@dynamic identifier;
@dynamic name;
@dynamic number;
@dynamic createdAt;
@dynamic updatedAt;
@dynamic body;
@dynamic repository;
@dynamic creator;
@dynamic organization;

@end

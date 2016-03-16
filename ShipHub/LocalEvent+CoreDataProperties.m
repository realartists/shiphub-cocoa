//
//  LocalEvent+CoreDataProperties.m
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalEvent+CoreDataProperties.h"

@implementation LocalEvent (CoreDataProperties)

@dynamic commitId;
@dynamic commitURL;
@dynamic createdAt;
@dynamic event;
@dynamic identifier;
@dynamic actor;
@dynamic assignee;
@dynamic labels;
@dynamic milestone;

@end

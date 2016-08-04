//
//  LocalReaction+CoreDataProperties.m
//  ShipHub
//
//  Created by James Howard on 8/3/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalReaction+CoreDataProperties.h"

@implementation LocalReaction (CoreDataProperties)

@dynamic identifier;
@dynamic content;
@dynamic createdAt;
@dynamic user;
@dynamic issue;
@dynamic comment;

@end

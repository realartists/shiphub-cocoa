//
//  LocalRepo+CoreDataProperties.m
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalRepo+CoreDataProperties.h"

@implementation LocalRepo (CoreDataProperties)

@dynamic fullName;
@dynamic hidden;
@dynamic identifier;
@dynamic name;
@dynamic private;
@dynamic repoDescription;
@dynamic shipNeedsWebhookHelp;
@dynamic assignees;
@dynamic issues;
@dynamic labels;
@dynamic milestones;
@dynamic owner;

@end

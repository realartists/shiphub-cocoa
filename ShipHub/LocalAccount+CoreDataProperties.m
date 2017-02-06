//
//  LocalAccount+CoreDataProperties.m
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalAccount+CoreDataProperties.h"

@implementation LocalAccount (CoreDataProperties)

@dynamic avatarURL;
@dynamic identifier;
@dynamic login;
@dynamic name;
@dynamic type;

@dynamic repos;

@dynamic actedEvents;
@dynamic assignable;
@dynamic assignedEvents;
@dynamic assignedIssues;
@dynamic closedIssues;
@dynamic comments;
@dynamic orgs;
@dynamic originatedIssues;
@dynamic reactions;
@dynamic createdProjects;

@dynamic shipNeedsWebhookHelp;
@dynamic users;
@dynamic projects;

@end

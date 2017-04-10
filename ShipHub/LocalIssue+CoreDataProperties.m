//
//  LocalIssue+CoreDataProperties.m
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalIssue+CoreDataProperties.h"

#import "LocalRepo.h"
#import "LocalAccount.h"
#import "IssueIdentifier.h"

@implementation LocalIssue (CoreDataProperties)

@dynamic body;
@dynamic closed;
@dynamic state;
@dynamic pullRequest;
@dynamic createdAt;
@dynamic identifier;
@dynamic locked;
@dynamic number;
@dynamic title;
@dynamic updatedAt;
@dynamic closedAt;
@dynamic shipReactionSummary;
@dynamic assignees;
@dynamic childRelationships;
@dynamic closedBy;
@dynamic labels;
@dynamic milestone;
@dynamic originator;
@dynamic relationships;
@dynamic repository;
@dynamic events;
@dynamic comments;
@dynamic upNext;
@dynamic notification;
@dynamic reactions;

@dynamic pullRequestIdentifier;
@dynamic maintainerCanModify;
@dynamic mergeable;
@dynamic mergeCommitSha;
@dynamic merged;
@dynamic mergedAt;
@dynamic mergedBy;

@dynamic base;
@dynamic head;

@end

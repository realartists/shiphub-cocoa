//
//  MetadataStore.h
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "User.h"
#import "Repo.h"
#import "Org.h"
#import "Milestone.h"
#import "Label.h"

@interface MetadataStore : NSObject

- (NSArray<Repo *> *)activeRepos;
- (NSArray<User *> *)assigneesForRepo:(Repo *)repo;
- (NSArray<User *> *)allAssignees;

- (User *)userWithIdentifier:(NSNumber *)identifier;
- (Org *)orgWithIdentifier:(NSNumber *)identifier;
- (Repo *)repoWithIdentifier:(NSNumber *)identifier;
- (Milestone *)milestoneWithIdentifier:(NSNumber *)identifier;

- (NSArray<User *> *)membersOfOrg:(Org *)org;

/* Returns the names of active milestones across all repos */
- (NSArray<NSString *> *)mergedMilestoneNames;

- (NSArray<Label *> *)mergedLabels;
- (NSArray<Label *> *)labelsForRepo:(Repo *)repo;

- (NSArray<Milestone *> *)activeMilestonesForRepo:(Repo *)repo;
- (Milestone *)milestoneWithTitle:(NSString *)title inRepo:(Repo *)repo;

- (NSArray<Account *> *)repoOwners;

- (NSArray<Repo *> *)reposForOwner:(Account *)owner;

@end

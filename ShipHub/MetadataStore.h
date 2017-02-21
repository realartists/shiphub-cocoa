//
//  MetadataStore.h
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Account.h"
#import "Repo.h"
#import "Milestone.h"
#import "Label.h"
#import "Project.h"

@interface MetadataStore : NSObject

- (NSArray<Repo *> *)activeRepos;
- (NSArray<Account *> *)assigneesForRepo:(Repo *)repo;
- (NSArray<Account *> *)allAssignees;

- (Account *)accountWithIdentifier:(NSNumber *)identifier;
- (Repo *)repoWithIdentifier:(NSNumber *)identifier;
- (Milestone *)milestoneWithIdentifier:(NSNumber *)identifier;

/* Returns the names of active milestones across all repos */
- (NSArray<NSString *> *)mergedMilestoneNames;
- (NSArray<Milestone *> *)mergedMilestonesWithTitle:(NSString *)title;

- (NSArray<Label *> *)mergedLabels;
- (NSArray<Label *> *)labelsForRepo:(Repo *)repo;
- (NSArray<Project *> *)projectsForRepo:(Repo *)repo;

- (NSArray<Milestone *> *)activeMilestonesForRepo:(Repo *)repo;
- (Milestone *)milestoneWithTitle:(NSString *)title inRepo:(Repo *)repo;

- (NSArray<Account *> *)repoOwners;

- (NSArray<Repo *> *)reposForOwner:(Account *)owner;
- (Repo *)repoWithFullName:(NSString *)fullName;

- (NSArray<Project *> *)projectsForOrg:(Account *)org;

- (NSArray<Repo *> *)hiddenRepos;
- (NSArray<Milestone *> *)hiddenMilestones;

- (id)objectWithManagedObject:(NSManagedObject *)obj;

@end

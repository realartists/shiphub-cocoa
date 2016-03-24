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

- (User *)userWithIdentifier:(NSNumber *)identifier;
- (Org *)orgWithIdentifier:(NSNumber *)identifier;
- (Repo *)repoWithIdentifier:(NSNumber *)identifier;
- (Milestone *)milestoneWithIdentifier:(NSNumber *)identifier;

- (NSArray<User *> *)membersOfOrg:(Org *)org;

- (NSArray<NSString *> *)mergedMilestoneNames;

- (NSArray<Label *> *)mergedLabels;
- (NSArray<Label *> *)labelsForRepo:(Repo *)repo;

- (NSArray<Milestone *> *)activeMilestonesForRepo:(Repo *)repo;

- (NSArray<Account *> *)repoOwners;

- (NSArray<Repo *> *)reposForOwner:(Account *)owner;

@end

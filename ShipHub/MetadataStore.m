//
//  MetadataStore.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "MetadataStore.h"

#import "Extras.h"

#import "LocalAccount.h"
#import "LocalUser.h"
#import "LocalOrg.h"
#import "LocalRepo.h"
#import "LocalLabel.h"
#import "LocalMilestone.h"
#import "LocalMetadata.h"

@interface MetadataStore ()

@property (strong) NSDictionary *usersByID;
@property (strong) NSDictionary *orgsByID;
@property (strong) NSDictionary *accountsByID;

@property (strong) NSDictionary *assigneesByRepoID;

@property (strong) NSArray *repoOwners;
@property (strong) NSDictionary *reposByOwnerID;

@property (strong) NSArray *repos;
@property (strong) NSDictionary *reposByID;

@property (strong) NSDictionary *milestonesByRepoID;
@property (strong) NSDictionary *labelsByRepoID;

@property (strong) NSArray *mergedLabels;
@property (strong) NSArray *mergedMilestoneNames;
@property (strong) NSDictionary *milestonesByID;

@property (strong) NSDictionary *orgIDToMembers;

@end

@implementation MetadataStore

static BOOL IsMetadataObject(id obj) {
    return [obj conformsToProtocol:@protocol(LocalMetadata)];
}

+ (BOOL)changeNotificationContainsMetadata:(NSNotification *)mocNote {
    
    NSDictionary *info = mocNote.userInfo;
    
    for (id obj in info[NSInsertedObjectsKey]) {
        if (IsMetadataObject(obj)) return YES;
    }
    
    for (id obj in info[NSUpdatedObjectsKey]) {
        if (IsMetadataObject(obj)) return YES;
    }
    
    for (id obj in info[NSDeletedObjectsKey]) {
        if (IsMetadataObject(obj)) return YES;
    }
    
    return NO;
}

// Read data out of ctx and store in immutable data objects accessible from any thread.
- (instancetype)initWithMOC:(NSManagedObjectContext *)moc {
    NSParameterAssert(moc);
    
    if (self = [super init]) {
        [moc performBlockAndWait:^{
            
            NSFetchRequest *reposFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalRepo"];
            NSArray *localRepos = [moc executeFetchRequest:reposFetch error:NULL];
            
            NSMutableArray *repos = [NSMutableArray arrayWithCapacity:localRepos.count];
            
            NSMutableDictionary *accountsByID = [NSMutableDictionary new];
            NSMutableDictionary *orgsByID = [NSMutableDictionary new];
            NSMutableDictionary *usersByID = [NSMutableDictionary new];
            NSMutableDictionary *assigneesByRepoID = [NSMutableDictionary new];
            NSMutableDictionary *milestonesByRepoID = [NSMutableDictionary new];
            NSMutableDictionary *labelsByRepoID = [NSMutableDictionary new];
            
            NSMutableSet *repoOwners = [NSMutableSet new];
            NSMutableDictionary *reposByOwnerID = [NSMutableDictionary new];
            
            for (LocalRepo *r in localRepos) {
                Repo *repo = [[Repo alloc] initWithLocalItem:r];
                [repos addObject:repo];
                
                NSMutableArray *assignees;
                assigneesByRepoID[r.identifier] = assignees = [NSMutableArray new];
                for (LocalUser *lu in r.assignees) {
                    User *u = usersByID[lu.identifier];
                    if (!u) {
                        u = [[User alloc] initWithLocalItem:lu];
                        usersByID[lu.identifier] = u;
                        accountsByID[lu.identifier] = u;
                    }
                    [assignees addObject:u];
                }
                
                NSMutableArray *milestones;
                milestonesByRepoID[r.identifier] = milestones = [NSMutableArray new];
                
                for (LocalMilestone *lm in r.milestones) {
                    Milestone *m = [[Milestone alloc] initWithLocalItem:lm];
                    [milestones addObject:m];
                }
                
                NSMutableArray *labels;
                labelsByRepoID[r.identifier] = labels = [NSMutableArray new];
                
                for (LocalLabel *ll in r.labels) {
                    Label *l = [[Label alloc] initWithLocalItem:ll];
                    [labels addObject:l];
                }
                
                LocalAccount *localOwner = r.owner;
                
                Account *owner = accountsByID[localOwner.identifier];
                if (!owner) {
                    if ([localOwner isKindOfClass:[LocalOrg class]]) {
                        owner = [[Org alloc] initWithLocalItem:localOwner];
                        orgsByID[localOwner.identifier] = owner;
                    } else {
                        owner = [[User alloc] initWithLocalItem:localOwner];
                        usersByID[localOwner.identifier] = owner;
                    }
                    accountsByID[localOwner.identifier] = owner;
                }
                [repoOwners addObject:owner];
                
                NSMutableArray *ownersList = reposByOwnerID[localOwner.identifier];
                if (!ownersList) {
                    reposByOwnerID[localOwner.identifier] = ownersList = [NSMutableArray new];
                }
                [ownersList addObject:repo];
            }
            
            _usersByID = usersByID;
            _orgsByID = orgsByID;
            _accountsByID = accountsByID;
            
            _assigneesByRepoID = assigneesByRepoID;
            
            _repoOwners = [repoOwners allObjects];
            
            _reposByOwnerID = reposByOwnerID;
            
            _repos = repos;
            
            _milestonesByRepoID = milestonesByRepoID;
            
            _labelsByRepoID = labelsByRepoID;
            
            NSMutableDictionary *mergedLabels = [NSMutableDictionary new];
            
            for (NSArray *la in [_labelsByRepoID allValues]) {
                for (Label *l in la) {
                    if (!mergedLabels[l.name]) {
                        mergedLabels[l.name] = l;
                    }
                }
            }
            
            _mergedLabels = [mergedLabels allValues];
            
            NSMutableSet *mergedMilestones = [NSMutableSet new];
            NSMutableDictionary *milestonesByID = [NSMutableDictionary new];
            for (NSArray *ma in [_milestonesByRepoID allValues]) {
                for (Milestone *m in ma) {
                    [mergedMilestones addObject:m.title];
                    milestonesByID[m.identifier] = m;
                }
            }
            
            _milestonesByID = milestonesByID;
            
            _mergedMilestoneNames = [mergedMilestones allObjects];
            
            _reposByID = [NSDictionary lookupWithObjects:_repos keyPath:@"identifier"];
            
            NSMutableDictionary *orgIDToMembers = [NSMutableDictionary new];
            
            for (Org *org in [orgsByID allValues]) {
                NSFetchRequest *membersFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalUser"];
                membersFetch.predicate = [NSPredicate predicateWithFormat:@"ANY orgs.identifier = %@", org.identifier];
                
                NSArray *localMembers = [moc executeFetchRequest:membersFetch error:NULL];
                
                NSMutableArray *members = [NSMutableArray new];
                orgIDToMembers[org.identifier] = members;
                for (LocalUser *lu in localMembers) {
                    User *u = usersByID[lu.identifier];
                    if (u) {
                        [members addObject:u];
                    }
                }
            }
            
            _orgIDToMembers = orgIDToMembers;
        }];
    }
    
    return self;
}

- (NSArray<Repo *> *)activeRepos {
    return _repos;
}

- (NSArray<User *> *)assigneesForRepo:(Repo *)repo {
    return _assigneesByRepoID[repo.identifier];
}

- (User *)userWithIdentifier:(NSNumber *)identifier {
    return _usersByID[identifier];
}

- (Org *)orgWithIdentifier:(NSNumber *)identifier {
    return _orgsByID[identifier];
}

- (Repo *)repoWithIdentifier:(NSNumber *)identifier {
    return _reposByID[identifier];
}

- (Milestone *)milestoneWithIdentifier:(NSNumber *)identifier {
    return _milestonesByID[identifier];
}

- (NSArray<User *> *)membersOfOrg:(Org *)org {
    return _orgIDToMembers[org.identifier];
}

- (NSArray<Milestone *> *)activeMilestonesForRepo:(Repo *)repo {
    return _milestonesByRepoID[repo.identifier];
}

- (NSArray<Repo *> *)reposForOwner:(Account *)owner {
    return _reposByOwnerID[owner.identifier];
}

@end

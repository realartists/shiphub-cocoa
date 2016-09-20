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
#import "LocalHidden.h"

@interface MetadataStore () {
    BOOL _allAssigneesNeedsSort;
    NSMutableArray *_allAssignees;
}

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

@property (strong) NSArray *hiddenRepos;
@property (strong) NSArray *hiddenMilestones;

@property (strong) NSDictionary *milestoneTitleToMilestones;

@end

@implementation MetadataStore

static BOOL IsMetadataObject(id obj) {
    return [obj conformsToProtocol:@protocol(LocalMetadata)] || [obj isKindOfClass:[LocalHidden class]];
}

static BOOL IsImportantUserChange(LocalUser *lu) {
    static NSSet *ignoredKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ignoredKeys = [NSSet setWithObjects:@"actedEvents", @"assignedEvents", @"assignedIssues", @"closedIssues", @"comments", @"originatedIssues", @"reactions", nil];
    });
    for (NSString *key in lu.changedValues) {
        return ![ignoredKeys containsObject:key];
    }
    return NO;
}

+ (BOOL)changeNotificationContainsMetadata:(NSNotification *)mocNote {
    
    __block BOOL result = NO;
    [mocNote enumerateModifiedObjects:^(id obj, CoreDataModificationType modType, BOOL *stop) {
        if (IsMetadataObject(obj)) {
            if (modType == CoreDataModificationTypeUpdated
                && [obj isKindOfClass:[LocalUser class]]
                && !IsImportantUserChange(obj)) {
                return;
            }
            result = YES;
            *stop = YES;
        }
    }];
    
    return result;
}

// Read data out of ctx and store in immutable data objects accessible from any thread.
- (instancetype)initWithMOC:(NSManagedObjectContext *)moc billingState:(BillingState)billingState {
    NSParameterAssert(moc);
    
    if (self = [super init]) {
        NSFetchRequest *reposFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalRepo"];
        reposFetch.predicate = [NSPredicate predicateWithFormat:@"name != nil && owner != nil"];
        
        NSArray *localRepos = [moc executeFetchRequest:reposFetch error:NULL];
        
        NSFetchRequest *usersFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalUser"];
        usersFetch.predicate = [NSPredicate predicateWithFormat:@"login != nil"];
        NSArray *localUsers = [moc executeFetchRequest:usersFetch error:NULL];
        
        NSMutableArray *repos = [NSMutableArray arrayWithCapacity:localRepos.count];
        
        NSMutableDictionary *accountsByID = [NSMutableDictionary new];
        NSMutableDictionary *orgsByID = [NSMutableDictionary new];
        NSMutableDictionary *localOrgsByID = [NSMutableDictionary new];
        NSDictionary *usersByID = [NSDictionary lookupWithObjects:[localUsers arrayByMappingObjects:^id(id obj) {
            return [[User alloc] initWithLocalItem:obj];
        }] keyPath:@"identifier"];
        [accountsByID addEntriesFromDictionary:usersByID];
        NSMutableDictionary *assigneesByRepoID = [NSMutableDictionary new];
        NSMutableDictionary *milestonesByRepoID = [NSMutableDictionary new];
        NSMutableDictionary *labelsByRepoID = [NSMutableDictionary new];
        NSMutableSet *allAssignees = [NSMutableSet new];
        
        NSMutableSet *repoOwners = [NSMutableSet new];
        NSMutableDictionary *reposByOwnerID = [NSMutableDictionary new];
        
        for (LocalRepo *r in localRepos) {
            NSMutableArray *assignees;
            assigneesByRepoID[r.identifier] = assignees = [NSMutableArray new];
            for (LocalUser *lu in r.assignees) {
                if (lu.login) {
                    User *u = usersByID[lu.identifier];
                    [assignees addObject:u];
                    [allAssignees addObject:u];
                }
            }
            
            NSMutableArray *milestones;
            milestonesByRepoID[r.identifier] = milestones = [NSMutableArray new];
            
            for (LocalMilestone *lm in r.milestones) {
                if (lm.title) {
                    Milestone *m = [[Milestone alloc] initWithLocalItem:lm];
                    [milestones addObject:m];
                }
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
                    localOrgsByID[localOwner.identifier] = localOwner;
                } else {
                    owner = usersByID[localOwner.identifier];
                }
                accountsByID[localOwner.identifier] = owner;
            }
            
            Repo *repo = [[Repo alloc] initWithLocalItem:r owner:owner billingState:billingState];
            [repos addObject:repo];
            
            if (!r.hidden) {
                [repoOwners addObject:owner];
                
                NSMutableArray *ownersList = reposByOwnerID[localOwner.identifier];
                if (!ownersList) {
                    reposByOwnerID[localOwner.identifier] = ownersList = [NSMutableArray new];
                }
                [ownersList addObject:repo];
            }
        }
        
        _usersByID = usersByID;
        _orgsByID = orgsByID;
        _accountsByID = accountsByID;
        
        _assigneesByRepoID = assigneesByRepoID;
        
        _repoOwners = [[repoOwners allObjects] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"login" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        
        _reposByOwnerID = reposByOwnerID;
        for (id ownerID in _reposByOwnerID) {
            NSMutableArray *r = _reposByOwnerID[ownerID];
            [r sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        }
        
        NSArray *notHiddenRepos = [repos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"hidden = NO AND restricted = NO"]];
        _repos = [notHiddenRepos sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"fullName" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        
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
        
        _reposByID = [NSDictionary lookupWithObjects:repos keyPath:@"identifier"];
        
        NSMutableSet *mergedMilestones = [NSMutableSet new];
        NSMutableDictionary *milestonesByID = [NSMutableDictionary new];
        NSMutableArray *hiddenMilestones = [NSMutableArray new];
        NSMutableDictionary *milestoneTitleToMilestones = [NSMutableDictionary new];
        for (NSNumber *repoID in _milestonesByRepoID) {
            NSMutableArray *ma = _milestonesByRepoID[repoID];
            Repo *repo = _reposByID[repoID];
            if (repo.hidden || repo.restricted) continue;
            [ma sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(localizedStandardCompare:)]]];
            for (Milestone *m in ma) {
                if (!m.closed && !m.hidden) {
                    [mergedMilestones addObject:m.title];
                    NSMutableArray *a = milestoneTitleToMilestones[m.title];
                    if (!a) milestoneTitleToMilestones[m.title] = a = [NSMutableArray new];
                    [a addObject:m];
                } else if (m.hidden) {
                    [hiddenMilestones addObject:m];
                }
                milestonesByID[m.identifier] = m;
            }
        }
        
        _milestonesByID = milestonesByID;
        
        _mergedMilestoneNames = [[mergedMilestones allObjects] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
        _milestoneTitleToMilestones = milestoneTitleToMilestones;
        
        NSMutableDictionary *orgIDToMembers = [NSMutableDictionary new];
        
        for (Org *org in [orgsByID allValues]) {
            NSSet *localMembers = [localOrgsByID[org.identifier] users];
            
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
        
        _allAssignees = [[allAssignees allObjects] mutableCopy];
        _allAssigneesNeedsSort = YES;
        
        _hiddenRepos = [[repos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"hidden = YES"]] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"fullName" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        _hiddenMilestones = hiddenMilestones;
    }
    
    return self;
}

- (NSArray<Repo *> *)activeRepos {
    return _repos;
}

- (NSArray<User *> *)assigneesForRepo:(Repo *)repo {
    return _assigneesByRepoID[repo.identifier];
}

- (NSArray<User *> *)allAssignees {
    @synchronized (_allAssignees) {
        if (_allAssigneesNeedsSort) {
            _allAssigneesNeedsSort = NO;
            [_allAssignees sortUsingComparator:^NSComparisonResult(User *a, User *b) {
                return [a.login localizedStandardCompare:b.login];
            }];
        }
        return _allAssignees;
    }
}

- (User *)userWithIdentifier:(NSNumber *)identifier {
    if (!identifier) return nil;
    return _usersByID[identifier];
}

- (Org *)orgWithIdentifier:(NSNumber *)identifier {
    if (!identifier) return nil;
    return _orgsByID[identifier];
}

- (Repo *)repoWithIdentifier:(NSNumber *)identifier {
    if (!identifier) return nil;
    return _reposByID[identifier];
}

- (Milestone *)milestoneWithIdentifier:(NSNumber *)identifier {
    return _milestonesByID[identifier];
}

- (NSArray<User *> *)membersOfOrg:(Org *)org {
    return _orgIDToMembers[org.identifier];
}

- (NSArray<Milestone *> *)activeMilestonesForRepo:(Repo *)repo {
    return [_milestonesByRepoID[repo.identifier] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"closed = NO"]];
}

- (Milestone *)milestoneWithTitle:(NSString *)title inRepo:(Repo *)repo {
    return [[_milestonesByRepoID[repo.identifier] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title = %@", title] limit:1] firstObject];
}

- (NSArray<Milestone *> *)mergedMilestonesWithTitle:(NSString *)title {
    return _milestoneTitleToMilestones[title];
}

- (NSArray<Repo *> *)reposForOwner:(Account *)owner {
    return _reposByOwnerID[owner.identifier];
}

- (NSArray<Label *> *)labelsForRepo:(Repo *)repo {
    return _labelsByRepoID[repo.identifier];
}

- (User *)userWithLocalUser:(LocalUser *)lu {
    if (!lu) return nil;
    
    User *u = [self userWithIdentifier:lu.identifier];
    if (!u) {
        u = [[User alloc] initWithLocalItem:lu];
    }
    return u;
}

@end

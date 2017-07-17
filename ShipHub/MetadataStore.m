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
#import "LocalRepo.h"
#import "LocalLabel.h"
#import "LocalMilestone.h"
#import "LocalMetadata.h"
#import "LocalHidden.h"
#import "LocalProject.h"
#import "LocalBilling.h"

@interface MetadataStore () {
    BOOL _allAssigneesNeedsSort;
    NSMutableArray *_allAssignees;
}

@property (strong) NSDictionary *accountsByID;

@property (strong) NSDictionary *assigneesByRepoID;

@property (strong) NSArray *repoOwners;
@property (strong) NSDictionary *reposByOwnerID;

@property (strong) NSArray *repos;
@property (strong) NSDictionary *reposByID;

@property (strong) NSDictionary *milestonesByRepoID;
@property (strong) NSDictionary *labelsByRepoID;
@property (strong) NSDictionary *projectsByRepoID;

@property (strong) NSArray *mergedLabels;
@property (strong) NSArray *mergedMilestoneNames;
@property (strong) NSDictionary *milestonesByID;

@property (strong) NSDictionary *orgIDToProjects;

@property (strong) NSArray *hiddenRepos;
@property (strong) NSArray *hiddenMilestones;

@property (strong) NSDictionary *milestoneTitleToMilestones;

@property (strong) NSDictionary *managedIDToObject;

@end

@implementation MetadataStore

static BOOL IsMetadataObject(id obj) {
    return [obj conformsToProtocol:@protocol(LocalMetadata)]
        || [obj isKindOfClass:[LocalHidden class]]
        || [obj isKindOfClass:[LocalBilling class]];
}

static BOOL IsImportantUserChange(LocalAccount *lu) {
//    assignable
//    orgs
//    projects
//    repos
//    users
//    
    static NSSet *allowedRelKeys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        allowedRelKeys = [NSSet setWithObjects:@"assignable", @"orgs", @"projects", @"repos", @"users", nil];
    });
    for (NSString *key in lu.changedValues) {
        BOOL isRelationship = lu.entity.relationshipsByName[key] != nil;
        if (!isRelationship || [allowedRelKeys containsObject:key]) {
            return YES;
        }
    }
    return NO;
}

+ (BOOL)changeNotificationContainsMetadata:(NSNotification *)mocNote {
    
    __block BOOL result = NO;
    [mocNote enumerateModifiedObjects:^(id obj, CoreDataModificationType modType, BOOL *stop) {
        if (IsMetadataObject(obj)) {
            if (modType == CoreDataModificationTypeUpdated
                && [obj isKindOfClass:[LocalAccount class]]
                && !IsImportantUserChange(obj)) {
                return;
            }
            result = YES;
            *stop = YES;
        }
    }];
    
    return result;
}

static id<NSCopying> UniqueIDForManagedObject(NSManagedObject *obj) {
    static BOOL hasPersistentStoreConnectionPool;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        hasPersistentStoreConnectionPool = &NSPersistentStoreConnectionPoolMaxSizeKey != NULL;
    });
    
    if (hasPersistentStoreConnectionPool) {
        return obj.objectID;
    } else {
        return obj.objectID.URIRepresentation;
    }
}

// Read data out of ctx and store in immutable data objects accessible from any thread.
- (instancetype)initWithMOC:(NSManagedObjectContext *)moc billingState:(BillingState)billingState currentUserIdentifier:(NSNumber *)currentUserIdentifier
{
    NSParameterAssert(moc);
    NSParameterAssert(currentUserIdentifier);
    
    if (self = [super init]) {
        NSMutableDictionary *managedIDToObject = [NSMutableDictionary new];
        void (^noteManagedObject)(NSManagedObject *, id) = ^(NSManagedObject *mObj, id obj){
            managedIDToObject[UniqueIDForManagedObject(mObj)] = obj;
        };
        
        NSFetchRequest *reposFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalRepo"];
        reposFetch.predicate = [NSPredicate predicateWithFormat:@"name != nil AND owner.login != nil AND disabled = NO"];
        
        NSArray *localRepos = [moc executeFetchRequest:reposFetch error:NULL];
        
        NSFetchRequest *accountsFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalAccount"];
        accountsFetch.predicate = [NSPredicate predicateWithFormat:@"login != nil"];
        NSArray *localAccounts = [moc executeFetchRequest:accountsFetch error:NULL];
        
        NSMutableArray *repos = [NSMutableArray arrayWithCapacity:localRepos.count];
        
        NSDictionary *accountsByID = [NSDictionary lookupWithObjects:[localAccounts arrayByMappingObjects:^id(id obj) {
            Account *u = [[Account alloc] initWithLocalItem:obj];
            noteManagedObject(obj, u);
            return u;
        }] keyPath:@"identifier"];
        
        NSMutableDictionary *assigneesByRepoID = [NSMutableDictionary new];
        NSMutableDictionary *milestonesByRepoID = [NSMutableDictionary new];
        NSMutableDictionary *projectsByRepoID = [NSMutableDictionary new];
        NSMutableDictionary *labelsByRepoID = [NSMutableDictionary new];
        NSMutableSet *allAssignees = [NSMutableSet new];
        
        NSMutableSet *repoOwners = [NSMutableSet new];
        NSMutableDictionary *reposByOwnerID = [NSMutableDictionary new];
        
        for (LocalRepo *r in localRepos) {
            BOOL currentUserAssignable = NO;
            NSMutableArray *assignees;
            assigneesByRepoID[r.identifier] = assignees = [NSMutableArray new];
            for (LocalAccount *lu in r.assignees) {
                if (lu.login) {
                    Account *u = accountsByID[lu.identifier];
                    [assignees addObject:u];
                    [allAssignees addObject:u];
                }
                if (!currentUserAssignable && [lu.identifier isEqual:currentUserIdentifier]) {
                    currentUserAssignable = YES;
                }
            }
            
            NSMutableArray *milestones;
            milestonesByRepoID[r.identifier] = milestones = [NSMutableArray new];
            
            for (LocalMilestone *lm in r.milestones) {
                if (lm.title) {
                    Milestone *m = [[Milestone alloc] initWithLocalItem:lm];
                    noteManagedObject(lm, m);
                    [milestones addObject:m];
                }
            }
            
            NSMutableArray *labels;
            labelsByRepoID[r.identifier] = labels = [NSMutableArray new];
            
            for (LocalLabel *ll in r.labels) {
                if (ll.name && ll.color) {
                    Label *l = [[Label alloc] initWithLocalItem:ll];
                    noteManagedObject(ll, l);
                    [labels addObject:l];
                }
            }
            
            LocalAccount *localOwner = r.owner;
            
            Account *owner = accountsByID[localOwner.identifier];
            
            Repo *repo = [[Repo alloc] initWithLocalItem:r owner:owner billingState:billingState canPush:currentUserAssignable];
            noteManagedObject(r, repo);
            [repos addObject:repo];
            
            NSMutableArray *projects;
            projectsByRepoID[r.identifier] = projects = [NSMutableArray new];
            for (LocalProject *lp in r.projects) {
                if (lp.name && lp.number) {
                    Project *p = [[Project alloc] initWithLocalItem:lp owningRepo:repo];
                    noteManagedObject(lp, p);
                    [projects addObject:p];
                }
            }
            
            if (!r.hidden && owner) {
                [repoOwners addObject:owner];
                
                NSMutableArray *ownersList = reposByOwnerID[localOwner.identifier];
                if (!ownersList) {
                    reposByOwnerID[localOwner.identifier] = ownersList = [NSMutableArray new];
                }
                [ownersList addObject:repo];
            }
        }
        
        NSMutableDictionary *orgIDToProjects = [NSMutableDictionary new];
        for (LocalAccount *lo in localAccounts) {
            if ([lo.type isEqualToString:@"Organization"]) {
                NSMutableArray *projects = [NSMutableArray new];
                for (LocalProject *lp in lo.projects) {
                    if (lp.name && lp.number) {
                        Project *p = [[Project alloc] initWithLocalItem:lp owningOrg:accountsByID[lo.identifier]];
                        [projects addObject:p];
                    }
                }
                orgIDToProjects[lo.identifier] = projects;
            }
        }
        _orgIDToProjects = orgIDToProjects;
        
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
        
        _projectsByRepoID = projectsByRepoID;
        
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
                
        _allAssignees = [[allAssignees allObjects] mutableCopy];
        _allAssigneesNeedsSort = YES;
        
        _hiddenRepos = [[repos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"hidden = YES"]] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"fullName" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        _hiddenMilestones = hiddenMilestones;
        
        _managedIDToObject = managedIDToObject;
    }
    
    return self;
}

- (NSArray<Repo *> *)activeRepos {
    return _repos;
}

- (NSArray<Account *> *)assigneesForRepo:(Repo *)repo {
    return _assigneesByRepoID[repo.identifier];
}

- (NSArray<Account *> *)allAssignees {
    @synchronized (_allAssignees) {
        if (_allAssigneesNeedsSort) {
            _allAssigneesNeedsSort = NO;
            [_allAssignees sortUsingComparator:^NSComparisonResult(Account *a, Account *b) {
                return [a.login localizedStandardCompare:b.login];
            }];
        }
        return _allAssignees;
    }
}

- (Account *)accountWithIdentifier:(NSNumber *)identifier {
    if (!identifier) return nil;
    return _accountsByID[identifier];
}

- (Repo *)repoWithIdentifier:(NSNumber *)identifier {
    if (!identifier) return nil;
    return _reposByID[identifier];
}

- (Milestone *)milestoneWithIdentifier:(NSNumber *)identifier {
    return _milestonesByID[identifier];
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

- (Repo *)repoWithFullName:(NSString *)fullName {
    return [[_repos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"fullName = %@", fullName] limit:1] firstObject];
}

- (NSArray<Label *> *)labelsForRepo:(Repo *)repo {
    return _labelsByRepoID[repo.identifier];
}

- (NSArray<Project *> *)projectsForRepo:(Repo *)repo {
    return _projectsByRepoID[repo.identifier];
}

- (NSArray<Project *> *)projectsForOrg:(Account *)org {
    NSParameterAssert(org.accountType == AccountTypeOrg);
    return _orgIDToProjects[org.identifier];
}

- (Account *)accountWithLocalAccount:(LocalAccount *)la {
    if (!la) return nil;
    
    Account *a = [self accountWithIdentifier:la.identifier];
    if (!a) {
        a = [[Account alloc] initWithLocalItem:la];
    }
    return a;
}

- (id)objectWithManagedObject:(NSManagedObject *)obj {
    id<NSCopying> uid = UniqueIDForManagedObject(obj);
    
    return _managedIDToObject[uid];
}

@end

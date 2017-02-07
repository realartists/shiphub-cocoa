//
//  MapAccount1to2.m
//  ShipHub
//
//  Created by James Howard on 2/6/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "MapAccount1to2.h"

#import "Extras.h"

@implementation MapAccount1to2

- (NSMutableDictionary *)doppelgangers:(NSMigrationManager *)manager {
    static NSString *dgKey = @"LocalAccount_doppelgangers";
    NSMutableDictionary *doppelgangers = nil;
    if (nil == (doppelgangers = manager.userInfo[dgKey])) {
        doppelgangers = [NSMutableDictionary new];
        NSDictionary *mine = @{dgKey:doppelgangers};
        if (manager.userInfo) {
            manager.userInfo = [manager.userInfo dictionaryByAddingEntriesFromDictionary:mine];
        } else {
            manager.userInfo = mine;
        }
    }
    return doppelgangers;
}

- (BOOL)beginEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
#if DEBUG
    NSArray *validSources = @[@"LocalOrg", @"LocalUser", @"LocalAccount"];
    NSAssert([validSources containsObject:[mapping sourceEntityName]], @"Must map from LocalAccount, LocalOrg, or LocalUser");
    NSAssert([[mapping destinationEntityName] isEqualToString:@"LocalAccount"], @"Must map to LocalAccount");
#endif
    
    return YES;
}

- (void)mapSharedAttributesFrom:(NSManagedObject *)src to:(NSManagedObject *)dst
{
    [dst setValue:[src valueForKey:@"identifier"] forKey:@"identifier"];
    [dst setValue:[src valueForKey:@"avatarURL"] forKey:@"avatarURL"];
    [dst setValue:[src valueForKey:@"name"] forKey:@"name"];
    [dst setValue:[src valueForKey:@"login"] forKey:@"login"];
}

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
    NSManagedObject *destAccount = nil;
    
    if ([sInstance.entity.name isEqualToString:@"LocalUser"]) {
        
        // check to make sure there isn't already an organization in the source store with this instance's identifier. if there is, ignore this one.
        
        NSNumber *myIdentifier = [sInstance valueForKey:@"identifier"];
        
        NSFetchRequest *alreadyExists = [NSFetchRequest fetchRequestWithEntityName:@"LocalOrg"];
        alreadyExists.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", myIdentifier];
        
        if (0 == [manager.sourceContext countForFetchRequest:alreadyExists error:error]) {
            
            // colliding org doesn't exist. ok to map.
            
            destAccount = [NSEntityDescription insertNewObjectForEntityForName:@"LocalAccount" inManagedObjectContext:manager.destinationContext];
            
            [self mapSharedAttributesFrom:sInstance to:destAccount];
            [destAccount setValue:@"User" forKey:@"type"];
            
        } else {
            // collided with an org. save it as a doppelganger so we can assign its related objects to their rightful owner later.
            NSMutableDictionary *doppelgangers = [self doppelgangers:manager];
            doppelgangers[myIdentifier] = sInstance;
        }
        
    } else if ([sInstance.entity.name isEqualToString:@"LocalOrg"]) {
        
        destAccount = [NSEntityDescription insertNewObjectForEntityForName:@"LocalAccount" inManagedObjectContext:manager.destinationContext];
        [self mapSharedAttributesFrom:sInstance to:destAccount];
        [destAccount setValue:@"Organization" forKey:@"type"];
        [destAccount setValue:[sInstance valueForKey:@"shipNeedsWebhookHelp"] forKey:@"shipNeedsWebhookHelp"];
        
    } else {
        DebugLog(@"Saw abstract LocalAccount");
        // no-op. Any non-associated instances don't map.
    }
    
    if (destAccount) {
        [manager associateSourceInstance:sInstance withDestinationInstance:destAccount forEntityMapping:mapping];
    }
    
    return YES;
}

- (BOOL)endInstanceCreationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
    return YES;
}

- (void)mapToManyRelationship:(NSString *)relationshipKey from:(NSManagedObject *)src to:(NSManagedObject *)dst manager:(NSMigrationManager *)manager
{
    NSRelationshipDescription *desc = src.entity.relationshipsByName[relationshipKey];
    NSAssert(desc != nil, @"Must find NSRelationshipDescription for relationship %@", relationshipKey);
    
    NSString *entityMappingName = nil;
    for (NSEntityMapping *mapping in manager.mappingModel.entityMappings) {
        if ([mapping.sourceEntityName isEqualToString:desc.destinationEntity.name]) {
            entityMappingName = mapping.name;
            break;
        }
    }
    
    NSAssert(entityMappingName != nil, @"Must find NSEntityMapping for relationship %@", relationshipKey);
    NSSet *srcObjs = [src valueForKey:relationshipKey];
    
    if (srcObjs) {
        NSArray *dstObjs = [manager destinationInstancesForEntityMappingNamed:entityMappingName sourceInstances:[srcObjs allObjects]];
        [dst setValue:[NSSet setWithArray:dstObjs] forKey:relationshipKey];
    }
}

- (void)mapUserRelationshipsFrom:(NSManagedObject *)src to:(NSManagedObject *)dst manager:(NSMigrationManager *)manager
{
    NSArray *toMany =
    @[@"actedEvents",
      @"assignable",
      @"assignedEvents",
      @"assignedIssues",
      @"closedIssues",
      @"comments",
      @"createdProjects",
      @"orgs",
      @"originatedIssues",
      @"queries",
      @"reactions",
      @"upNext"];
    
    for (NSString *relKey in toMany) {
        [self mapToManyRelationship:relKey from:src to:dst manager:manager];
    }
}

- (void)mapOrgRelationshipsFrom:(NSManagedObject *)src to:(NSManagedObject *)dst manager:(NSMigrationManager *)manager
{
    NSArray *toMany = @[@"projects", @"users"];
    
    for (NSString *relKey in toMany) {
        [self mapToManyRelationship:relKey from:src to:dst manager:manager];
    }
}

- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)dst entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
    NSParameterAssert(dst);
    
    NSManagedObject *src = [[manager sourceInstancesForEntityMappingNamed:mapping.name destinationInstances:@[dst]] firstObject];
    NSAssert(src != nil, @"Must have a source instance");
    
    if ([src.entity.name isEqualToString:@"LocalUser"]) {
        
        [self mapToManyRelationship:@"repos" from:src to:dst manager:manager];
        [self mapUserRelationshipsFrom:src to:dst manager:manager];
        
    } else if ([src.entity.name isEqualToString:@"LocalOrg"]) {
        
        [self mapOrgRelationshipsFrom:src to:dst manager:manager];
        
        NSManagedObject *doppelganger = [self doppelgangers:manager][[src valueForKey:@"identifier"]];
        
        if (doppelganger) {
            // see if the doppelganger has (some of) our repos
            id srcRepos = [src valueForKey:@"repos"];
            id doppelRepos = [doppelganger valueForKey:@"repos"];
            
            if ([srcRepos isKindOfClass:[NSArray class]]) srcRepos = [NSSet setWithArray:srcRepos];
            if ([doppelRepos isKindOfClass:[NSArray class]]) doppelRepos = [NSSet setWithArray:doppelRepos];
            
            NSMutableSet *allRepos = [NSMutableSet new];
            
            if ([srcRepos count]) [allRepos unionSet:srcRepos];
            if ([doppelRepos count]) [allRepos unionSet:doppelRepos];
            
            NSArray *dstObjs = [manager destinationInstancesForEntityMappingNamed:@"LocalRepoToLocalRepo" sourceInstances:[allRepos allObjects]];
            [dst setValue:[NSSet setWithArray:dstObjs] forKey:@"repos"];
            
            [self mapUserRelationshipsFrom:doppelganger to:dst manager:manager];
        }
        
    } else {
        NSAssert(NO, @"Should not have a destination instance for a source abstract LocalAccount");
    }
    
    return YES;
}

- (BOOL)endRelationshipCreationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
    return YES;
}

- (BOOL)performCustomValidationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
    return YES;
}

- (BOOL)endEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error {
    return YES;
}


@end

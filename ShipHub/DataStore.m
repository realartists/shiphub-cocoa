//
//  DataStore.m
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "DataStore.h"

#import "Auth.h"
#import "Extras.h"
#import "Reachability.h"
#import "ServerConnection.h"
#import "SyncConnection.h"
#import "GHSyncConnection.h"
#import "MetadataStoreInternal.h"
#import "NSPredicate+Extras.h"

#import "LocalAccount.h"
#import "LocalUser.h"
#import "LocalOrg.h"
#import "LocalRepo.h"
#import "LocalLabel.h"
#import "LocalMilestone.h"
#import "LocalIssue.h"
#import "LocalEvent.h"
#import "LocalComment.h"
#import "LocalRelationship.h"

#import "Issue.h"
#import "Error.h"

NSString *const DataStoreWillBeginMigrationNotification = @"DataStoreWillBeginMigrationNotification";
NSString *const DataStoreDidEndMigrationNotification = @"DataStoreDidEndMigrationNotification";
NSString *const DataStoreMigrationProgressKey = @"DataStoreMigrationProgressKey";

NSString *const DataStoreActiveDidChangeNotification = @"DataStoreActiveDidChangeNotification";

NSString *const DataStoreDidUpdateMetadataNotification = @"DataStoreDidUpdateMetadataNotification";
NSString *const DataStoreMetadataKey = @"DataStoreMetadataKey";

NSString *const DataStoreDidUpdateProblemsNotification = @"DataStoreDidUpdateProblemsNotification";
NSString *const DataStoreUpdatedProblemsKey = @"DataStoreUpdatedProblemsKey";
NSString *const DataStoreUpdateProblemSourceKey = @"DataStoreUpdateProblemSourceKey";

NSString *const DataStoreDidUpdateOutboxNotification = @"DataStoreDidUpdateOutboxNotification";
NSString *const DataStoreOutboxResolvedProblemIdentifiersKey = @"DataStoreOutboxResolvedProblemIdentifiersKey";

NSString *const DataStoreDidPurgeNotification = @"DataStoreDidPurgeNotification";
NSString *const DataStoreWillPurgeNotification = @"DataStoreWillPurgeNotification";

NSString *const DataStoreDidUpdateMyQueriesNotification = @"DataStoreDidUpdateQueriesNotification";

NSString *const DataStoreCannotOpenDatabaseNotification = @"DataStoreCannotOpenDatabaseNotification";

NSString *const DataStoreWillBeginInitialMetadataSync = @"DataStoreWillBeginInitialMetadataSync";
NSString *const DataStoreDidEndInitialMetadataSync = @"DataStoreDidEndInitialMetadataSync";

NSString *const DataStoreWillBeginNetworkActivityNotification = @"DataStoreWillBeginNetworkActivityNotification";
NSString *const DataStoreDidEndNetworkActivityNotification = @"DataStoreDidEndNetworkActivityNotification";
NSString *const DataStoreDidUpdateProgressNotification = @"DataStoreDidUpdateProgressNotification";

NSString *const DataStoreNeedsMandatorySoftwareUpdateNotification = @"DataStoreNeedsMandatorySoftwareUpdateNotification";

/*
 Change History:
 1: First Version
 */
static const NSInteger CurrentLocalModelVersion = 1;

@interface DataStore () <SyncConnectionDelegate> {
    NSManagedObjectModel *_mom;
    NSPersistentStore *_persistentStore;
    NSPersistentStoreCoordinator *_persistentCoordinator;
    NSManagedObjectContext *_moc;
    
    NSLock *_metadataLock;
    
    dispatch_queue_t _needsMetadataQueue;
    NSMutableArray *_needsMetadataItems;
    
    dispatch_queue_t _queryUploadQueue;
    NSMutableSet *_queryUploadProcessing; // only manipulated within _moc.
    NSMutableArray *_needsQuerySyncItems;
    dispatch_queue_t _needsQuerySyncQueue;

    NSString *_purgeVersion;
    
    NSMutableDictionary *_localMetadataCache; // only manipulated within _moc.
    
    NSInteger _initialSyncProgress;
    
    BOOL _sentNetworkActivityBegan;
    double _problemSyncProgress;
}

@property (strong) Auth *auth;
@property (strong) ServerConnection *serverConnection;
@property (strong) SyncConnection *syncConnection;

@property (readwrite, strong) NSDate *lastUpdated;

@property (readwrite, strong) MetadataStore *metadataStore;

@end

@implementation DataStore

static DataStore *sActiveStore = nil;

+ (DataStore *)activeStore {
    DataStore *threadLocalStore = [[NSThread currentThread] threadDictionary][@"ActiveDataStore"];
    if (threadLocalStore) {
        return threadLocalStore;
    }
    return sActiveStore;
}

- (void)activate {
    sActiveStore = self;
    [[Defaults defaults] setObject:_auth.account.login forKey:DefaultsLastUsedAccountKey];
    [[Defaults defaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreActiveDidChangeNotification object:self];
}

- (void)activateThreadLocal {
    NSThread *thread = [NSThread currentThread];
    thread.threadDictionary[@"ActiveDataStore"] = self;
}

- (void)deactivateThreadLocal {
    NSThread *thread = [NSThread currentThread];
    if (self == thread.threadDictionary[@"ActiveDataStore"]) {
        [thread.threadDictionary removeObjectForKey:@"ActiveDataStore"];
    }
}

- (void)deactivate {
    sActiveStore = nil;
}

- (BOOL)isActive {
    return sActiveStore == self;
}

+ (Class)serverConnectionClass {
    return [ServerConnection class];
}

+ (Class)syncConnectionClass {
    if (DefaultsServerEnvironment() == ServerEnvironmentLocal) {
        return [GHSyncConnection class];
    } else {
        return [SyncConnection class];
    }
}

+ (DataStore *)storeWithAuth:(Auth *)auth {
    return [[self alloc] initWithAuth:auth];
}

- (id)initWithAuth:(Auth *)auth {
    NSParameterAssert(auth);
    NSParameterAssert(auth.account.login);
    
    if (self = [super init]) {
        _auth = auth;
        
        _needsMetadataItems = [NSMutableArray array];
        _needsMetadataQueue = dispatch_queue_create("DataStore.ResolveMetadata", NULL);
        _metadataLock = [[NSLock alloc] init];
        _queryUploadQueue = dispatch_queue_create("DataStore.UploadQuery", NULL);
        _queryUploadProcessing = [NSMutableSet set];
        _needsQuerySyncItems = [NSMutableArray array];
        _needsQuerySyncQueue = dispatch_queue_create("DataStore.ResolveQueries", NULL);
        _localMetadataCache = [NSMutableDictionary dictionary];
        
        if (![self openDB]) {
            return nil;
        }
        
        self.serverConnection = [[[[self class] serverConnectionClass] alloc] initWithAuth:_auth];
        self.syncConnection = [[[[self class] syncConnectionClass] alloc] initWithAuth:_auth];
        self.syncConnection.delegate = self;
        
        [self loadMetadata];
        [self updateSyncConnectionWithVersions];
    }
    return self;
}

- (BOOL)isOffline {
    return ![[Reachability sharedInstance] isReachable];
}

- (BOOL)isValid {
    return _auth.authState == AuthStateValid && ![self isMigrating];
}

- (NSString *)_dbPath {
    NSAssert(_auth.account.shipIdentifier, @"Must have a user identifier to open the database");
    
    NSString *dbname = [NSString stringWithFormat:@"%@.db", ServerEnvironmentToString(DefaultsServerEnvironment())];
    
    NSString *basePath = [[[Defaults defaults] stringForKey:DefaultsLocalStoragePathKey] stringByExpandingTildeInPath];
    NSString *path = [basePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@", _auth.account.shipIdentifier, dbname]];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    return path;
}

- (BOOL)openDB {
    return [self openDBForceRecreate:NO];
}

static NSString *const StoreVersion = @"DataStoreVersion";
static NSString *const PurgeVersion = @"PurgeVersion";
static NSString *const LastUpdated = @"LastUpdated";

- (BOOL)openDBForceRecreate:(BOOL)forceRecreate {
    NSString *filename = [self _dbPath];
    
    DebugLog(@"Opening DB at path: %@", filename);
    
    NSURL *momURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"LocalModel" withExtension:@"momd"];
    _mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:momURL];
    NSAssert(_mom, @"Must load mom from %@", momURL);
    
    _persistentCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_mom];
    NSAssert(_persistentCoordinator, @"Must load coordinator");
    NSURL *storeURL = [NSURL fileURLWithPath:filename];
    NSError *err = nil;
    
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES };
    
    // Determine if a migration is needed
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:storeURL options:options error:&err];
    if (!_purgeVersion) {
        _purgeVersion = sourceMetadata[PurgeVersion];
    }
    NSInteger previousStoreVersion = sourceMetadata ? [sourceMetadata[StoreVersion] integerValue] : CurrentLocalModelVersion;
    
    if (previousStoreVersion > CurrentLocalModelVersion) {
        ErrLog(@"Database has version %td, which is newer than client version %td.", previousStoreVersion, CurrentLocalModelVersion);
        [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreCannotOpenDatabaseNotification object:nil /*nil because we're about to fail to init*/ userInfo:nil];
        return NO;
    }
    
    if (forceRecreate) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:[storeURL path]]) {
            [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&err];
            if (err) {
                ErrLog(@"Error deleting obsolete db: %@", err);
            }
        }
        previousStoreVersion = CurrentLocalModelVersion;
    }
    
    NSPersistentStore *store = _persistentStore = [_persistentCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:@"Default" URL:storeURL options:options error:&err];
    if (!store) {
        ErrLog(@"Error adding persistent store: %@", err);
        if (!forceRecreate) {
            ErrLog(@"Will force database recreation");
            return [self openDBForceRecreate:YES];
        } else {
            return NO;
        }
    }
    
    NSMutableDictionary *storeMetadata = [sourceMetadata mutableCopy] ?: [NSMutableDictionary dictionary];
    storeMetadata[StoreVersion] = @(CurrentLocalModelVersion);
    if (_purgeVersion) {
        storeMetadata[PurgeVersion] = _purgeVersion;
    }
    [_persistentCoordinator setMetadata:storeMetadata forPersistentStore:store];
    
    _lastUpdated = storeMetadata[LastUpdated];
    
    _moc = [[SerializedManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    _moc.persistentStoreCoordinator = _persistentCoordinator;
    _moc.undoManager = nil; // don't care about undo-ing here, and it costs performance to have an undo manager.
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mocDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:_moc];
    
    BOOL needsSnapshotRebuild = NO;
    BOOL needsKeywordUsageRebuild = NO;
    BOOL needsABResync = NO;
    BOOL needsToWatchOwnQueries = NO;
    BOOL needsMetadataResync = NO;
    
    (void)needsToWatchOwnQueries;
    
    if (needsSnapshotRebuild || needsKeywordUsageRebuild) {
        _migrating = YES;
        NSProgress *progress = [NSProgress progressWithTotalUnitCount:-1];
        [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreWillBeginMigrationNotification object:self userInfo:@{DataStoreMigrationProgressKey : progress }];
        [self migrationRebuildSnapshots:needsSnapshotRebuild rebuildKeywordUsage:needsKeywordUsageRebuild withProgress:progress completion:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                _migrating = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidEndMigrationNotification object:self userInfo:@{DataStoreMigrationProgressKey : progress }];
            });
        }];
    }
    
    if (needsMetadataResync) {
        DebugLog(@"Forcing metadata resync");
        [_moc performBlockAndWait:^{
#if !INCOMPLETE
            [self setLatestSequence:0 syncType:@"addressBook"];
            [self setLatestSequence:0 syncType:@"classifications"];
            [self setLatestSequence:0 syncType:@"components"];
            [self setLatestSequence:0 syncType:@"milestones"];
            [self setLatestSequence:0 syncType:@"priorities"];
            [self setLatestSequence:0 syncType:@"states"];
#endif
            [_moc save:NULL];
        }];
    } else if (needsABResync) {
        DebugLog(@"Forcing address book resync");
        [_moc performBlockAndWait:^{
#if !INCOMPLETE
            [self setLatestSequence:0 syncType:@"addressBook"];
#endif
            [_moc save:NULL];
        }];
    }
    
    return YES;
}

- (void)migrationRebuildSnapshots:(BOOL)rebuildSnapshots
              rebuildKeywordUsage:(BOOL)rebuildKeywordUsage
                     withProgress:(NSProgress *)progress
                       completion:(dispatch_block_t)completion
{
    NSAssert(rebuildSnapshots || rebuildKeywordUsage, @"Should be rebuilding at least something here");
    
    [self loadMetadata];
    [_moc performBlock:^{
        [self activateThreadLocal];
        
        CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
        NSError *err = nil;
        
#if !INCOMPLETE
        NSArray *problemIdentifiers = nil;
        if (rebuildSnapshots) {
            // Fetch the distinct set of problemIdentifiers in the database
            NSFetchRequest *distinct = [NSFetchRequest fetchRequestWithEntityName:@"LocalLogEntry"];
            distinct.resultType = NSDictionaryResultType;
            distinct.returnsDistinctResults = YES;
            distinct.propertiesToFetch = @[@"problemIdentifier"];
            problemIdentifiers = [_moc executeFetchRequest:distinct error:&err];
            if (err) {
                ErrLog(@"Error fetching distinct problemIdentifiers: %@", err);
            }
        }
        
        progress.totalUnitCount = [problemIdentifiers count] + (rebuildKeywordUsage ? 1 : 0);
        
        if (rebuildSnapshots) {
            int64_t i = 0;
            for (NSDictionary *result in problemIdentifiers) {
                [self updateSnapshot:result[@"problemIdentifier"]];
                i++;
                progress.completedUnitCount = i;
            }
        }
        
        if (rebuildKeywordUsage) {
            [self rebuildKeywordUsage];
            progress.completedUnitCount += 1;
        }
#endif
        
        err = nil;
        [_moc save:&err];
        if (err) {
            ErrLog(@"Error saving updated snapshots: %@", err);
        }
        
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        DebugLog(@"Completed migration (snapshots:%d keywords:%d) in %.3fs", rebuildSnapshots, rebuildKeywordUsage, (end-start));
        (void)start; (void)end;
        
        [self deactivateThreadLocal];
    } completion:completion];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadMetadata {
    self.metadataStore = [[MetadataStore alloc] initWithMOC:_moc];
}

- (void)updateSyncConnectionWithVersions {
    [_moc performBlock:^{
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalSyncVersion"];
        fetch.resultType = NSDictionaryResultType;
        NSError *err = nil;
        NSArray *results = [_moc executeFetchRequest:fetch error:&err];
        if (err) {
            ErrLog("%@", err);
        }
        
        // Convert [ { "type" : "user", "version" : 1234 }, ... ] =>
        // { "user" : 1234, ... }
        NSMutableDictionary *all = [NSMutableDictionary dictionaryWithCapacity:results.count];
        for (NSDictionary *pair in results) {
            all[pair[@"type"]] = pair[@"version"];
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.syncConnection syncWithVersions:all];
        });
    }];
}

// Must be called on _moc.
// Does not call save:
- (void)setLatestSyncVersion:(int64_t)version syncType:(NSString *)syncType {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalSyncVersion"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"type = %@", syncType];
    fetchRequest.fetchLimit = 1;
    
    NSError *err = nil;
    NSArray *results = [_moc executeFetchRequest:fetchRequest error:&err];
    if (err) {
        ErrLog(@"%@", err);
        return;
    }
    
    NSManagedObject *obj = [results firstObject];
    if (!obj) {
        obj = [NSEntityDescription insertNewObjectForEntityForName:@"LocalSyncVersion" inManagedObjectContext:_moc];
        [obj setValue:syncType forKey:@"type"];
    }
    [obj setValue:@(version) forKey:@"version"];

}

// Must be called on _moc.
// Does not call save:
- (NSArray *)createPlaceholderEntitiesWithName:(NSString *)entityName withIdentifiers:(NSArray *)identifiers {
    NSParameterAssert(entityName);
    NSParameterAssert(identifiers);
    
    NSError *error = nil;
    NSFetchRequest *existing = [NSFetchRequest fetchRequestWithEntityName:entityName];
    existing.resultType = NSDictionaryResultType;
    existing.propertiesToFetch = @[@"identifier"];
    NSArray *ids = [[_moc executeFetchRequest:existing error:&error] arrayByMappingObjects:^id(id obj) {
        return [obj objectForKey:@"identifier"];
    }];
    
    if (error) {
        ErrLog(@"entity: %@ error: %@", entityName, error);
        return nil;
    }
    
    NSMutableSet *toCreate = [NSMutableSet setWithArray:identifiers];
    [toCreate minusSet:[NSSet setWithArray:ids]];
    
    NSMutableArray *created = [NSMutableArray arrayWithCapacity:toCreate.count];
    for (id identifier in toCreate) {
        NSManagedObject *newEntity = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:_moc];
        [newEntity setValue:identifier forKey:@"identifier"];
        [created addObject:newEntity];
    }
    
    return created;
}

- (void)syncConnection:(SyncConnection *)sync receivedRootIdentifiers:(NSDictionary *)rootIdentifiers version:(int64_t)version {
    DebugLog(@"%@\nversion: %qd", rootIdentifiers, version);
    [_moc performBlock:^{
        NSError *error = nil;
        
        // delete users who no longer exist.
        NSFetchRequest *deleteUsers = [NSFetchRequest fetchRequestWithEntityName:@"LocalUser"];
        deleteUsers.predicate = [NSPredicate predicateWithFormat:@"!(identifier IN %@)", rootIdentifiers[@"users"]];
        [_moc batchDeleteEntitiesWithRequest:deleteUsers error:&error];
        
        if (error) ErrLog(@"%@", error);
        error = nil;
        
        [self createPlaceholderEntitiesWithName:@"LocalUser" withIdentifiers:rootIdentifiers[@"users"]];
        
        
        // delete orgs that no longer exist.
        NSFetchRequest *deleteOrgs = [NSFetchRequest fetchRequestWithEntityName:@"LocalOrg"];
        deleteOrgs.predicate = [NSPredicate predicateWithFormat:@"!(identifier IN %@)", rootIdentifiers[@"orgs"]];
        [_moc batchDeleteEntitiesWithRequest:deleteOrgs error:&error];
        
        if (error) ErrLog("%@", error);
        error = nil;
        
        [self createPlaceholderEntitiesWithName:@"LocalOrg" withIdentifiers:rootIdentifiers[@"orgs"]];
        
        [self setLatestSyncVersion:version syncType:@"root"];
        
        [_moc save:&error];
        
        if (error) ErrLog("%@", error);
    }];
}

// Must be called on _moc.
// Does not call save:
- (void)updateLabelsOn:(NSManagedObject *)owner fromDicts:(NSArray *)lDicts relationship:(NSRelationshipDescription *)relationship {
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalLabel"];
    fetch.predicate = [NSPredicate predicateWithFormat:@"%K = %@", relationship.inverseRelationship.name, owner];
    NSError *error = nil;
    NSArray *existingLabels = [_moc executeFetchRequest:fetch error:&error];
    if (error) ErrLog("%@", error);
    
    NSDictionary *existingLookup = [NSDictionary lookupWithObjects:existingLabels keyPath:@"name"];
    NSDictionary *lDictLookup = [NSDictionary lookupWithObjects:lDicts keyPath:@"name"];
    
    NSMutableSet *allNames = [NSMutableSet setWithArray:[existingLookup allKeys]];
    [allNames addObjectsFromArray:[lDictLookup allKeys]];
    
    NSMutableArray *relatedLabels = [[NSMutableArray alloc] initWithCapacity:lDicts.count];
    
    for (NSString *name in allNames) {
        NSDictionary *d = lDictLookup[name];
        LocalLabel *ll = existingLookup[name];
        
        if (ll && d) {
            [ll mergeAttributesFromDictionary:d];
            [relatedLabels addObject:ll];
        } else if (ll && !d) {
            [_moc deleteObject:ll];
        } else if (!ll && d) {
            ll = [NSEntityDescription insertNewObjectForEntityForName:@"LocalLabel" inManagedObjectContext:_moc];
            [ll mergeAttributesFromDictionary:d];
            [relatedLabels addObject:ll];
        }
    }
    
    [owner setValue:[NSSet setWithArray:relatedLabels] forKey:@"labels"];
}

// Must be called on _moc.
// Does not call save:
- (void)updateRelationshipsOn:(NSManagedObject *)obj fromSyncDict:(NSDictionary *)syncDict {
    
    NSDictionary *relationships = obj.entity.relationshipsByName;
    
    for (NSString *key in [relationships allKeys]) {
        NSRelationshipDescription *rel = relationships[key];
        
        if ([key isEqualToString:@"labels"]) {
            // labels are ... *sigh* ... special
            [self updateLabelsOn:(LocalRepo *)obj fromDicts:syncDict[@"labels"] relationship:rel];
            continue;
        }
        
        NSString *syncDictKey = rel.userInfo[@"jsonKey"];
        if (!syncDictKey) syncDictKey = key;
        
        if (rel.toMany) {
            // Anything that cascades is considered a "strong" relationship, which
            // implies the ability to delete and create referenced objects as needed.
            BOOL cascade = rel.deleteRule == NSCascadeDeleteRule;
            
            // to many relationships refer by identifiers or by actual populated objects that have identifiers
            NSArray *related = syncDict[syncDictKey];
            
            if (!related) {
                continue;
            }
            
            NSArray *relatedIDs = nil;
            NSDictionary *relatedLookup = nil;
            if ([[related firstObject] isKindOfClass:[NSDictionary class]]) {
                relatedIDs = [related arrayByMappingObjects:^id(NSDictionary *x) {
                    return x[@"identifier"];
                }];
                relatedLookup = [NSDictionary lookupWithObjects:related keyPath:@"identifier"];
            } else {
                relatedIDs = related;
            }
            if (!relatedIDs) relatedIDs = @[];
            NSSet *relatedIDSet = [NSSet setWithArray:relatedIDs];
            
            if (cascade) {
                // delete anything that's no longer being referenced
                id<NSFastEnumeration> originalRelatedObjs = [obj valueForKey:key];
                
                for (NSManagedObject *relObj in originalRelatedObjs) {
                    id identifier = [relObj valueForKey:@"identifier"];
                    if (![relatedIDSet containsObject:identifier]) {
                        DebugLog(@"Will delete relationship %@ to %@ (%@)", rel, relObj, identifier);
                        [_moc deleteObject:relObj];
                    }
                }
            }
            
            // find everything in relatedIDs that already exists
            NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:rel.destinationEntity.name];
            fetch.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", relatedIDs];
            
            NSError *error = nil;
            NSArray *existing = [_moc executeFetchRequest:fetch error:&error];
            NSMutableArray *relatedObjs = [NSMutableArray arrayWithArray:existing];
            if (error) ErrLog(@"%@", error);
            
            NSMutableSet *toCreate = [relatedIDs mutableCopy];
            for (NSManagedObject *relObj in existing) {
                NSString *identifier = [relObj valueForKey:@"identifier"];
                NSDictionary *updates = relatedLookup[identifier];
                if (updates) {
                    [relObj mergeAttributesFromDictionary:updates];
                }
                [toCreate removeObject:identifier];
            }
            
            for (id identifier in toCreate) {
                DebugLog(@"Creating %@ of id %@", rel.destinationEntity.name, identifier);
                NSManagedObject *relObj = [NSEntityDescription insertNewObjectForEntityForName:rel.destinationEntity.name inManagedObjectContext:_moc];
                [relObj setValue:identifier forKey:@"identifier"];
                NSDictionary *populate = relatedLookup[identifier];
                if (populate) {
                    [relObj mergeAttributesFromDictionary:populate];
                }
                [relatedObjs addObject:relObj];
            }
            
            [obj setValue:[NSSet setWithArray:relatedObjs] forKey:key];
            
        } else /* rel.toOne */ {
            id related = syncDict[syncDictKey];
            
            if (!related) continue;
            
            NSDictionary *populate = nil;
            NSString *relatedID = related;
            if ([related isKindOfClass:[NSDictionary class]]) {
                populate = related;
                relatedID = populate[@"identifier"];
            } else if (related == [NSNull null]) {
                [obj setValue:nil forKey:key];
                relatedID = nil;
            }
            
            if (relatedID != nil) {
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:rel.destinationEntity.name];
                fetch.predicate = [NSPredicate predicateWithFormat:@"identifier == %@", relatedID];
                fetch.fetchLimit = 1;
                
                NSError *error = nil;
                
                NSManagedObject *relObj = [[_moc executeFetchRequest:fetch error:&error] firstObject];
                if (relObj) {
                    [obj setValue:relObj forKey:key];
                } else {
                    DebugLog(@"Creating %@ of id %@", rel.destinationEntity.name, relatedID);
                    relObj = [NSEntityDescription insertNewObjectForEntityForName:rel.destinationEntity.name inManagedObjectContext:_moc];
                    [relObj setValue:relatedID forKey:@"identifier"];
                    if (populate) {
                        [relObj mergeAttributesFromDictionary:populate];
                    }
                }
            }
        }
    }
}

- (void)syncConnection:(SyncConnection *)sync receivedSyncObjects:(NSArray *)objs type:(NSString *)type version:(int64_t)version {
    DebugLog(@"%@: %@\nversion:%qd", type, objs, version);
    
    [_moc performBlock:^{
        NSError *error = nil;
        
        NSMutableSet *toCreate = [NSMutableSet setWithArray:objs];
        
        NSString *entityName = [NSString stringWithFormat:@"Local%@", [type PascalCase]];
        if (_mom.entitiesByName[entityName] == nil) {
            DebugLog(@"Received unknown sync type: %@", type);
            return;
        }
        
        // Fetch all of the existing managed objects that we are going to update.
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
        fetch.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@.identifier", objs];
        
        NSArray *mObjs = [_moc executeFetchRequest:fetch error:&error];
        
        if (error) ErrLog("%@", error);
        error = nil;
        
        NSDictionary *lookup = [NSDictionary lookupWithObjects:objs keyPath:@"identifier"];
        for (NSManagedObject *mObj in mObjs) {
            NSDictionary *objDict = lookup[[mObj valueForKey:@"identifier"]];
            [mObj mergeAttributesFromDictionary:objDict];
            [self updateRelationshipsOn:mObj fromSyncDict:objDict];
            [toCreate removeObject:objDict];
        }
        
        for (NSDictionary *objDict in toCreate) {
            NSManagedObject *mObj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:_moc];
            [mObj mergeAttributesFromDictionary:objDict];
            [self updateRelationshipsOn:mObj fromSyncDict:objDict];
        }
        
        [self setLatestSyncVersion:version syncType:type];
        
        [_moc save:&error];
        if (error) ErrLog("%@", error);
    }];
}

- (void)syncConnectionDidConnect:(SyncConnection *)sync {
    
}

- (void)syncConnectionDidDisconnect:(SyncConnection *)sync {
    
}

- (void)mocDidChange:(NSNotification *)note {
    //DebugLog(@"%@", note);
    
    if ([MetadataStore changeNotificationContainsMetadata:note]) {
        DebugLog(@"Updating metadata store");
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            MetadataStore *store = [[MetadataStore alloc] initWithMOC:_moc];
            self.metadataStore = store;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSDictionary *userInfo = @{ DataStoreMetadataKey : store };
                [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidUpdateMetadataNotification object:self userInfo:userInfo];
            });
        });
    }
}

- (void)issuesMatchingPredicate:(NSPredicate *)predicate completion:(void (^)(NSArray<Issue*> *issues, NSError *error))completion {
    return [self issuesMatchingPredicate:predicate sortDescriptors:@[] completion:completion];
}

- (void)issuesMatchingPredicate:(NSPredicate *)predicate sortDescriptors:(NSArray<NSSortDescriptor*> *)sortDescriptors completion:(void (^)(NSArray<Issue*> *issues, NSError *error))completion {
    __block NSArray *results = nil;
    __block NSError *error = nil;
    [_moc performBlock:^{
        @try {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
            fetchRequest.predicate = [predicate predicateByFoldingExpressions];
            fetchRequest.sortDescriptors = sortDescriptors;
            
            NSError *err = nil;
            NSArray *entities = [_moc executeFetchRequest:fetchRequest error:&err];
            if (err) {
                ErrLog(@"%@", err);
            }
            MetadataStore *ms = self.metadataStore;
            results = [entities arrayByMappingObjects:^id(LocalIssue *obj) {
                return [[Issue alloc] initWithLocalIssue:obj metadataStore:ms];
            }];
        } @catch (id exc) {
            error = [NSError shipErrorWithCode:ShipErrorCodeInvalidQuery];
            ErrLog(@"%@", exc);
        }
    } completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(results, error);
        });
    }];

}

- (void)countIssuesMatchingPredicate:(NSPredicate *)predicate completion:(void (^)(NSUInteger count, NSError *error))completion {
    __block NSUInteger result = 0;
    __block NSError *error = nil;
    [_moc performBlock:^{
        @try {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
            fetchRequest.predicate = [predicate predicateByFoldingExpressions];
            NSError *err = nil;
            result = [_moc countForFetchRequest:fetchRequest error:&err];
            
            if (err) {
                ErrLog(@"%@", err);
                result = 0;
            }
        } @catch (id exc) {
            error = [NSError shipErrorWithCode:ShipErrorCodeInvalidQuery];
            ErrLog(@"%@", exc);
        }
    } completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result, error);
        });
    }];
}

@end

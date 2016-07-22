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
#import "WSSyncConnection.h"
#import "MetadataStoreInternal.h"
#import "NSPredicate+Extras.h"
#import "JSON.h"
#import "TimeSeries.h"
#import "GHNotificationManager.h"

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
#import "LocalSyncVersion.h"
#import "LocalPriority.h"
#import "LocalNotification.h"

#import "Issue.h"
#import "IssueComment.h"
#import "IssueIdentifier.h"
#import "Repo.h"

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

NSString *const DataStoreDidUpdateMyUpNextNotification = @"DataStoreDidUpdateMyUpNextNotification";

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
@property (strong) GHNotificationManager *ghNotificationManager;

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
    if (ServerEnvironmentIsLocal()) {
        return [GHSyncConnection class];
    } else {
        return [WSSyncConnection class];
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
        
        _ghNotificationManager = [[GHNotificationManager alloc] initWithManagedObjectContext:_moc auth:_auth];
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
    
    NSString *dbname = [NSString stringWithFormat:@"%@.db", [[Defaults defaults] stringForKey:DefaultsServerKey]];
    
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
    (void)previousStoreVersion;
    
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
        NSError *err = nil;
        NSArray *results = [_moc executeFetchRequest:fetch error:&err];
        if (err) {
            ErrLog("%@", err);
        }
        
        NSAssert(results.count <= 1, nil);
        
        NSData *data = [[results firstObject] data];
        NSDictionary *versions = nil;
        
        if (data) {
            err = nil;
            versions = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if (err) {
                ErrLog(@"%@", err);
            }
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.syncConnection syncWithVersions:versions?:@{}];
        });
    }];
}

// Must be called on _moc.
// Does not call save:
- (void)updateSyncVersions:(NSDictionary *)versions {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalSyncVersion"];
    
    NSError *err = nil;
    NSArray *results = [_moc executeFetchRequest:fetchRequest error:&err];
    if (err) {
        ErrLog(@"%@", err);
        return;
    }
    
    LocalSyncVersion *obj = [results firstObject] ?: [NSEntityDescription insertNewObjectForEntityForName:@"LocalSyncVersion" inManagedObjectContext:_moc];
    
    obj.data = [NSJSONSerialization dataWithJSONObject:versions?:@{} options:0 error:NULL];
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
        BOOL noPopulate = [rel.userInfo[@"noPopulate"] boolValue];
        
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
                if (updates && !noPopulate) {
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
                    if (populate && !noPopulate) {
                        [relObj mergeAttributesFromDictionary:populate];
                    }
                } else {
                    NSString *relName = rel.destinationEntity.name;
                    if (rel.destinationEntity.abstract) {
                        NSString *type = populate[@"type"];
                        if (type) {
                            relName = [NSString stringWithFormat:@"Local%@", [type PascalCase]];
                            if (!_mom.entitiesByName[relName]) {
                                for (NSEntityDescription *sub in rel.destinationEntity.subentities) {
                                    NSString *jsonType = sub.userInfo[@"jsonType"];
                                    if ([jsonType isEqualToString:@"type"]) {
                                        relName = sub.name;
                                        break;
                                    }
                                }
                            }
                            if (!_mom.entitiesByName[relName]) {
                                DebugLog(@"Cannot resolve concrete entity for abstract relationship %@ (%@)", rel, populate);
                                relName = nil;
                            }
                        } else {
                            DebugLog(@"Cannot resolve concrete entity for abstract relationship %@", rel);
                            relName = nil;
                        }
                    }
                    
                    if (relName) {
                        DebugLog(@"Creating %@ of id %@", rel.destinationEntity.name, relatedID);
                        relObj = [NSEntityDescription insertNewObjectForEntityForName:relName inManagedObjectContext:_moc];
                        [relObj setValue:relatedID forKey:@"identifier"];
                        if (populate) {
                            [relObj mergeAttributesFromDictionary:populate];
                        }
                    }
                }
            }
        }
    }
}

- (void)addLabel:(NSDictionary *)label
       repoOwner:(NSString *)repoOwner
        repoName:(NSString *)repoName
      completion:(void (^)(NSDictionary *label, NSError *error))completion {
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/%@/labels", repoOwner, repoName];
    [self.serverConnection perform:@"POST" on:endpoint body:label completion:^(id jsonResponse, NSError *error) {
        if (jsonResponse) {
            [_moc performBlock:^{
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalRepo"];
                fetch.predicate = [NSPredicate predicateWithFormat:@"fullName = %@",
                                   [NSString stringWithFormat:@"%@/%@", repoOwner, repoName]];
                fetch.fetchLimit = 1;

                NSError *fetchError;
                NSArray *results = [_moc executeFetchRequest:fetch error:&fetchError];
                NSAssert(results != nil, @"Failed to fetch repo: %@", error);
                LocalRepo *localRepo = (LocalRepo *)[results firstObject];

                LocalLabel *localLabel = [NSEntityDescription insertNewObjectForEntityForName:@"LocalLabel"
                                                                       inManagedObjectContext:_moc];
                localLabel.name = label[@"name"];
                localLabel.color = label[@"color"];
                localLabel.repo = localRepo;

                NSError *saveError;
                if ([_moc save:&saveError]) {
                    RunOnMain(^{
                        completion(jsonResponse, nil);
                    });
                } else {
                    ErrLog(@"Failed to save: %@", saveError);
                    RunOnMain(^{
                        completion(nil, saveError);
                    });
                }
            }];
        } else {
            RunOnMain(^{
                completion(nil, error);
            });
        }
    }];
}

// Must be called on _moc. Does not call save. Does not update sync version
- (void)writeSyncObjects:(NSArray<SyncEntry *> *)objs {
    
    for (SyncEntry *e in objs) {
        NSError *error = nil;
        
        NSString *type = e.entityName;
        NSString *entityName = [NSString stringWithFormat:@"Local%@", [type PascalCase]];
        if (_mom.entitiesByName[entityName] == nil) {
            DebugLog(@"Received unknown sync type: %@", type);
            continue;
        }
        
        id data = e.data;
        
        NSNumber *identifier = nil;
        if ([data isKindOfClass:[NSNumber class]]) {
            identifier = data;
        } else {
            identifier = data[@"identifier"];
        }

        NSAssert(identifier != nil, @"identifier cannot be nil.");
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
        fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", identifier];
        fetch.fetchLimit = 1;
        
        NSManagedObject *mObj = [[_moc executeFetchRequest:fetch error:&error] firstObject];
        
        if (error) ErrLog(@"%@", error);
        error = nil;
        
        if (e.action == SyncEntryActionSet) {
            if (!mObj) {
                mObj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:_moc];
            }
            
            if ([data isKindOfClass:[NSDictionary class]]) {
                [mObj mergeAttributesFromDictionary:data];
                [self updateRelationshipsOn:mObj fromSyncDict:data];
            }
        } else /*e.action == SyncEntryActionDelete*/ {
            if (mObj) {
                [_moc deleteObject:mObj];
            }
        }
    }
}

- (void)syncConnection:(SyncConnection *)sync receivedEntries:(NSArray<SyncEntry *> *)entries versions:(NSDictionary *)versions progress:(double)progress
{
    [_moc performBlock:^{
        [self writeSyncObjects:entries];
        [self updateSyncVersions:versions];
        
        NSError *error = nil;
        [_moc save:&error];
        if (error) ErrLog("%@", error);
    }];
}

- (void)syncConnectionDidConnect:(SyncConnection *)sync {
    
}

- (void)syncConnectionDidDisconnect:(SyncConnection *)sync {
    
}

- (NSString *)issueFullIdentifier:(LocalIssue *)li {
    NSParameterAssert(li);
    return [NSString issueIdentifierWithOwner:li.repository.owner.login repo:li.repository.name number:li.number];
}

- (NSArray *)changedIssueIdentifiers:(NSNotification *)note {
    NSMutableSet *changed = [NSMutableSet new];
    
    [note enumerateModifiedObjects:^(id obj, CoreDataModificationType modType, BOOL *stop) {
        if ([obj isKindOfClass:[LocalIssue class]]) {
            [changed addObject:[self issueFullIdentifier:obj]];
        } else if ([obj isKindOfClass:[LocalEvent class]] || [obj isKindOfClass:[LocalComment class]]) {
            [changed addObject:[self issueFullIdentifier:[obj issue]]];
        } else if ([obj isKindOfClass:[LocalNotification class]]) {
            if ([obj issue] != nil) {
                [changed addObject:[obj issueFullIdentifier]];
            }
        }
    }];
    
    return changed.count > 0 ? [changed allObjects] : nil;
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
    
    // calculate which issues are affected by this change
    NSArray *changedIssueIdentifiers = [self changedIssueIdentifiers:note];
    if (changedIssueIdentifiers) {
        DebugLog(@"Updated issues %@", changedIssueIdentifiers);
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *userInfo = @{ DataStoreUpdatedProblemsKey : changedIssueIdentifiers };
            [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidUpdateProblemsNotification object:self userInfo:userInfo];
        });
    }
}

- (void)issuesMatchingPredicate:(NSPredicate *)predicate completion:(void (^)(NSArray<Issue*> *issues, NSError *error))completion {
    return [self issuesMatchingPredicate:predicate sortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES]] options:nil completion:completion];
}

- (void)issuesMatchingPredicate:(NSPredicate *)predicate sortDescriptors:(NSArray<NSSortDescriptor*> *)sortDescriptors completion:(void (^)(NSArray<Issue*> *issues, NSError *error))completion {
    return [self issuesMatchingPredicate:predicate sortDescriptors:sortDescriptors options:nil completion:completion];
}

- (void)issuesMatchingPredicate:(NSPredicate *)predicate sortDescriptors:(NSArray<NSSortDescriptor*> *)sortDescriptors options:(NSDictionary *)options completion:(void (^)(NSArray<Issue*> *issues, NSError *error))completion {
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
                return [[Issue alloc] initWithLocalIssue:obj metadataStore:ms options:options];
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

- (void)issueProgressMatchingPredicate:(NSPredicate *)predicate completion:(void (^)(double progress, NSError *error))completion {
    __block double progress = 0;
    __block NSError *error = nil;
    [_moc performBlock:^{
        @try {
            NSError *err = nil;
            
            NSPredicate *pred = [predicate predicateByFoldingExpressions];
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
            fetchRequest.predicate = pred;
            
            NSUInteger total = [_moc countForFetchRequest:fetchRequest error:&err];
            
            if (err) {
                ErrLog(@"%@", err);
                progress = -1.0;
            } else {
                fetchRequest.predicate = [pred and:[NSPredicate predicateWithFormat:@"closed = YES"]];
                NSUInteger closed = [_moc countForFetchRequest:fetchRequest error:&err];
                
                if (err) {
                    ErrLog(@"%@", err);
                    progress = -1.0;
                }
                
                if (total == 0) {
                    progress = -1.0;
                } else {
                    progress = (double)closed / (double)total;
                }
            }
        } @catch (id exc) {
            error = [NSError shipErrorWithCode:ShipErrorCodeInvalidQuery];
            ErrLog(@"%@", exc);
        }
    } completion:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(progress, error);
        });
    }];
}

- (void)loadFullIssue:(id)issueIdentifier completion:(void (^)(Issue *issue, NSError *error))completion {
    [_moc performBlock:^{
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
        fetchRequest.relationshipKeyPathsForPrefetching = @[@"events", @"comments"];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"fullIdentifier = %@", issueIdentifier];
        
        NSError *err = nil;
        NSArray *entities = [_moc executeFetchRequest:fetchRequest error:&err];
        
        if (err) ErrLog(@"%@", err);
        
        LocalIssue *i = [entities firstObject];
        
        if (i) {
            Issue *issue = [[Issue alloc] initWithLocalIssue:i metadataStore:self.metadataStore options:@{IssueOptionIncludeEventsAndComments:@YES}];
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(issue, nil);
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, [NSError shipErrorWithCode:ShipErrorCodeProblemDoesNotExist]);
            });
        }
    }];
}

- (void)checkForIssueUpdates:(id)issueIdentifier {
    [_syncConnection updateIssue:issueIdentifier];
}

- (void)storeSingleSyncObject:(id)obj type:(NSString *)type completion:(dispatch_block_t)completion
{
    [_moc performBlock:^{
        SyncEntry *e = [SyncEntry new];
        e.action = SyncEntryActionSet;
        e.entityName = type;
        e.data = obj;
        
        [self writeSyncObjects:@[e]];
        
        NSError *err = nil;
        [_moc save:&err];
        if (err) ErrLog(@"%@", err);
    } completion:completion];
}

#pragma mark - Issue Mutation

- (void)patchIssue:(NSDictionary *)patch issueIdentifier:(id)issueIdentifier completion:(void (^)(Issue *issue, NSError *error))completion
{
    NSParameterAssert(patch);
    NSParameterAssert(issueIdentifier);
    NSParameterAssert(completion);
    
    // PATCH /repos/:owner/:repo/issues/:number
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/%@/issues/%@", [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], [issueIdentifier issueNumber]];
    
    [self.serverConnection perform:@"PATCH" on:endpoint body:patch completion:^(id jsonResponse, NSError *error) {
        
        if (!error) {
            id myJSON = [JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]];
            
            [self storeSingleSyncObject:myJSON type:@"issue" completion:^{
                
                [self loadFullIssue:issueIdentifier completion:completion];
            }];
            
        } else {
            RunOnMain(^{
                completion(nil, error);
            });
        }
    }];
}

- (void)saveNewIssue:(NSDictionary *)issueJSON inRepo:(Repo *)r completion:(void (^)(Issue *issue, NSError *error))completion
{
    NSParameterAssert(issueJSON);
    NSParameterAssert(r);
    NSParameterAssert(completion);
    
    // POST /repos/:owner/:repo/issues
    
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/issues", r.fullName];
    [self.serverConnection perform:@"POST" on:endpoint body:issueJSON completion:^(id jsonResponse, NSError *error) {
    
        if (!error) {
            NSMutableDictionary *myJSON = [[JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]] mutableCopy];
            myJSON[@"repository"] = r.identifier;
            [self storeSingleSyncObject:myJSON type:@"issue" completion:^{
                
                id issueIdentifier = [NSString stringWithFormat:@"%@#%@", r.fullName, myJSON[@"number"]];
                
                [self loadFullIssue:issueIdentifier completion:completion];
            }];
        } else {
            RunOnMain(^{
                completion(nil, error);
            });
        }
        
    }];
}

- (void)deleteComment:(NSNumber *)commentIdentifier inIssue:(id)issueIdentifier completion:(void (^)(NSError *error))completion
{
    NSParameterAssert(commentIdentifier);
    NSParameterAssert(issueIdentifier);
    NSParameterAssert(completion);
    
    // DELETE /repos/:owner/:repo/issues/comments/:commentIdentifier
    
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/%@/issues/comments/%@", [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], commentIdentifier];
    [self.serverConnection perform:@"DELETE" on:endpoint body:nil completion:^(id jsonResponse, NSError *error) {
        if (!error) {
            
            [_moc performBlock:^{
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalComment"];
                
                fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", commentIdentifier];
                fetch.fetchLimit = 1;
                
                NSError *err = nil;
                LocalComment *lc = [[_moc executeFetchRequest:fetch error:&err] firstObject];;
                
                if (err) {
                    ErrLog(@"%@", err);
                }
                
                if (lc) {
                    [_moc deleteObject:lc];
                }
            }];
        }
        
        RunOnMain(^{
            completion(error);
        });
    }];
}

- (void)postComment:(NSString *)body inIssue:(NSString *)issueIdentifier completion:(void (^)(IssueComment *comment, NSError *error))completion
{
    NSParameterAssert(body);
    NSParameterAssert(issueIdentifier);
    NSParameterAssert(completion);
    
    // POST /repos/:owner/:repo/issues/:number/comments
    
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/%@/issues/%@/comments", [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], [issueIdentifier issueNumber]];
    
    [self.serverConnection perform:@"POST" on:endpoint body:@{@"body": body} completion:^(id jsonResponse, NSError *error) {
        
        if (!error) {
            
            [_moc performBlock:^{
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
                fetch.predicate = [NSPredicate predicateWithFormat:@"fullIdentifier = %@", issueIdentifier];
                fetch.fetchLimit = 1;
                
                NSError *err = nil;
                LocalIssue *issue = [[_moc executeFetchRequest:fetch error:&err] firstObject];
                
                if (err) ErrLog(@"%@", err);
                
                if (issue) {
                    NSMutableDictionary *d = [jsonResponse mutableCopy];
                    d[@"issue"] = issue.identifier;
                    
                    d = [JSON parseObject:d withNameTransformer:[JSON githubToCocoaNameTransformer]];
                    
                    SyncEntry *e = [SyncEntry new];
                    e.action = SyncEntryActionSet;
                    e.entityName = @"comment";
                    e.data = d;
                    
                    [self writeSyncObjects:@[e]];
                    
                    NSFetchRequest *fetch2 = [NSFetchRequest fetchRequestWithEntityName:@"LocalComment"];
                    fetch2.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", d[@"identifier"]];
                    err = nil;
                    LocalComment *lc = [[_moc executeFetchRequest:fetch2 error:&err] firstObject];
                    if (err) ErrLog(@"%@", err);
                    
                    IssueComment *ic = nil;
                    if (lc) {
                         ic = [[IssueComment alloc] initWithLocalComment:lc metadataStore:self.metadataStore];
                    }
                    
                    err = nil;
                    [_moc save:&err];
                    if (err) ErrLog(@"%@", err);
                    
                    RunOnMain(^{
                        completion(ic, nil);
                    });
                } else {
                    RunOnMain(^{
                        completion(nil, nil);
                    });
                }
            }];
            
        } else {
            RunOnMain(^{
                completion(nil, error);
            });
        }
    }];
}

- (void)editComment:(NSNumber *)commentIdentifier body:(NSString *)newCommentBody inIssue:(NSString *)issueIdentifier completion:(void (^)(IssueComment *comment, NSError *error))completion
{
    NSParameterAssert(commentIdentifier);
    NSParameterAssert(newCommentBody);
    NSParameterAssert(issueIdentifier);
    NSParameterAssert(completion);
    
    // PATCH /repos/:owner/:repo/issues/comments/:commentIdentifier
    
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/%@/issues/comments/%@", [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], commentIdentifier];
    
    [self.serverConnection perform:@"PATCH" on:endpoint body:@{ @"body" : newCommentBody } completion:^(id jsonResponse, NSError *error)
    {
        if (!error) {
            [_moc performBlock:^{
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalComment"];
                fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", commentIdentifier];
                fetch.fetchLimit = 1;
                
                NSError *err = nil;
                LocalComment *lc = [[_moc executeFetchRequest:fetch error:&err] firstObject];
                if (err) ErrLog(@"%@", err);
                
                id d = [JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]];
                
                IssueComment *ic = nil;
                if (lc) {
                    [lc mergeAttributesFromDictionary:d];
                    ic = [[IssueComment alloc] initWithLocalComment:lc metadataStore:self.metadataStore];
                    err = nil;
                    [_moc save:&err];
                    if (err) ErrLog(@"%@", err);
                }
                
                RunOnMain(^{
                    completion(ic, nil);
                });
            }];
        } else {
            RunOnMain(^{
                completion(nil, error);
            });
        }
    }];
}

#pragma mark - Time Series

- (void)timeSeriesMatchingPredicate:(NSPredicate *)predicate startDate:(NSDate *)startDate endDate:(NSDate *)endDate completion:(void (^)(TimeSeries *series, NSError *error))completion {
    [_moc performBlock:^{
        NSError *error = nil;
        @try {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
            fetchRequest.predicate = [TimeSeries timeSeriesPredicateWithPredicate:[predicate predicateByFoldingExpressions] startDate:startDate endDate:endDate];
            fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]];
            
            NSError *err = nil;
            NSArray *entities = [_moc executeFetchRequest:fetchRequest error:&err];
            if (err) {
                ErrLog(@"%@", err);
                error = error;
            }
            MetadataStore *ms = self.metadataStore;
            NSArray<Issue *> *issues = [entities arrayByMappingObjects:^id(LocalIssue *obj) {
                return [[Issue alloc] initWithLocalIssue:obj metadataStore:ms];
            }];
            
            TimeSeries *ts = [[TimeSeries alloc] initWithPredicate:predicate startDate:startDate endDate:endDate];
            [ts selectRecordsFrom:issues];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error==nil?ts:nil, error);
            });
            
        } @catch (id exc) {
            error = [NSError shipErrorWithCode:ShipErrorCodeInvalidQuery];
            ErrLog(@"%@", exc);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil, error);
            });
        }
    }];
}

#pragma mark - Up Next

- (void)addToUpNext:(NSArray<NSString *> *)issueIdentifiers atHead:(BOOL)atHead completion:(void (^)(NSError *error))completion {
    NSParameterAssert(issueIdentifiers);
    NSAssert([issueIdentifiers count] > 0, @"Must pass in at least one issue identifier");
    
    [_moc performBlock:^{
        __block NSError *err = nil;
        
        dispatch_block_t complete = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(err);
            });
        };
        
        NSFetchRequest *meRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalUser"];
        meRequest.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", [[User me] identifier]];
        meRequest.fetchLimit = 1;
        
        LocalUser *me = [[_moc executeFetchRequest:meRequest error:&err] firstObject];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        if (!me) {
            err = [NSError shipErrorWithCode:ShipErrorCodeInternalInconsistencyError];
            ErrLog(@"Cannot find me");
            complete();
            return;
        }
        
        NSPredicate *mePredicate = [NSPredicate predicateWithFormat:@"user = %@", me];
        NSFetchRequest *existingRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalPriority"];
        existingRequest.predicate = [mePredicate and:[NSPredicate predicateWithFormat:@"issue.fullIdentifier IN %@", issueIdentifiers]];
        
        NSDictionary *existing = [NSDictionary lookupWithObjects:[_moc executeFetchRequest:existingRequest error:&err] keyPath:@"issue.fullIdentifier"];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        NSFetchRequest *minMaxRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalPriority"];
        if (atHead) {
            minMaxRequest.predicate = [mePredicate and:[NSPredicate predicateWithFormat:@"priority = min(priority)"]];
        } else {
            minMaxRequest.predicate = [mePredicate and:[NSPredicate predicateWithFormat:@"priority = max(priority)"]];
        }
        minMaxRequest.resultType = NSDictionaryResultType;
        minMaxRequest.propertiesToFetch = @[@"priority"];
        minMaxRequest.fetchLimit = 1;
        
        NSNumber *minMax = [[[_moc executeFetchRequest:minMaxRequest error:&err] firstObject] objectForKey:@"priority"];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        double increment = 1.0;
        double start = [minMax doubleValue];
        double offset = increment * (1.0 + (double)issueIdentifiers.count);
        if (atHead) offset = -offset;
        start = start + offset;
        
        NSMutableSet *neededIssueIdentifiers = [NSMutableSet setWithArray:issueIdentifiers];
        [neededIssueIdentifiers minusSet:[NSSet setWithArray:existing.allKeys]];
        
        NSFetchRequest *issuesFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
        issuesFetch.predicate = [NSPredicate predicateWithFormat:@"fullIdentifier IN %@", neededIssueIdentifiers];
        NSDictionary *missingIssues = [NSDictionary lookupWithObjects:[_moc executeFetchRequest:issuesFetch error:&err] keyPath:@"fullIdentifier"];
        
        double priority = start;
        for (NSString *issueIdentifier in issueIdentifiers) {
            LocalPriority *mObj = existing[issueIdentifier];
            if (!mObj) {
                LocalIssue *issue = missingIssues[issueIdentifier];
                if (issue) {
                    mObj = [NSEntityDescription insertNewObjectForEntityForName:@"LocalPriority" inManagedObjectContext:_moc];
                    mObj.user = me;
                    mObj.issue = issue;
                }
            }
            mObj.priority = @(priority);
            priority += increment;
        }
        
        [_moc save:&err];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil);
            [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidUpdateMyUpNextNotification object:self];
        });
    }];
}

- (void)removeFromUpNext:(NSArray<NSString *> *)issueIdentifiers completion:(void (^)(NSError *error))completion {
    NSParameterAssert(issueIdentifiers);
    NSAssert(issueIdentifiers.count > 0, @"Must pass in at least 1 issueIdentifier");
    
    [_moc performBlock:^{
        __block NSError *err = nil;
        
        dispatch_block_t complete = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(err);
            });
        };
        
        User *me = [User me];
        
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalPriority"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"user.identifier = %@ AND issue.fullIdentifier IN %@", me.identifier, issueIdentifiers];
        
        [_moc batchDeleteEntitiesWithRequest:fetch error:&err];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        [_moc save:&err];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(err);
            [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidUpdateMyUpNextNotification object:self];
        });
    }];
}

- (void)insertIntoUpNext:(NSArray<NSString *> *)issueIdentifiers aboveIssueIdentifier:(NSString *)aboveIssueIdentifier completion:(void (^)(NSError *error))completion
{
    if (!aboveIssueIdentifier) {
        [self addToUpNext:issueIdentifiers atHead:NO completion:completion];
        return;
    }
    
    [_moc performBlock:^{
        
        __block NSError *err = nil;
        
        dispatch_block_t complete = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(err);
            });
        };
        
        NSFetchRequest *meRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalUser"];
        meRequest.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", [[User me] identifier]];
        meRequest.fetchLimit = 1;
        
        LocalUser *me = [[_moc executeFetchRequest:meRequest error:&err] firstObject];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        if (!me) {
            err = [NSError shipErrorWithCode:ShipErrorCodeInternalInconsistencyError];
            ErrLog(@"Cannot find me");
            complete();
            return;
        }
        
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalPriority"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"user = %@", me];
        fetch.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"priority" ascending:YES]];
        
        NSArray *upNext = [_moc executeFetchRequest:fetch error:&err];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        NSDictionary *lookup = [NSDictionary lookupWithObjects:upNext keyPath:@"issue.fullIdentifier"];
        NSSet *movingIdentifiers = [NSSet setWithArray:issueIdentifiers];
        NSMutableSet *neededIssueIdentifiers = [movingIdentifiers mutableCopy];
        [neededIssueIdentifiers minusSet:[NSSet setWithArray:[lookup allKeys]]];
        
        NSFetchRequest *issuesFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
        issuesFetch.predicate = [NSPredicate predicateWithFormat:@"fullIdentifier IN %@", neededIssueIdentifiers];
        NSDictionary *missingIssues = [NSDictionary lookupWithObjects:[_moc executeFetchRequest:issuesFetch error:&err] keyPath:@"fullIdentifier"];
        
        LocalPriority *context = lookup[aboveIssueIdentifier];
        
        NSInteger i = context != nil ? [upNext indexOfObjectIdenticalTo:context] : NSNotFound;
        
        double increment = 1.0;
        double start = context.priority.doubleValue;
        double offset = increment * (1.0 + (double)issueIdentifiers.count);
        
        BOOL reorderAll = NO;
        
        if (i == 0) {
            // go more negative
            offset = -offset;
            start += offset;
            
        } else if (i == NSNotFound || i == upNext.count) {
            // go more positive
            start += offset;
            
        } else {
            // need to insert the new items in the space in between
            LocalPriority *before = upNext[i-1];
            LocalPriority *after = context;
            increment = (after.priority.doubleValue - before.priority.doubleValue) / (1.0 + issueIdentifiers.count);
            start = before.priority.doubleValue + increment;
            
            if (increment < 0.00001) {
                reorderAll = YES;
            }
        }
        
        
        if (reorderAll) {
            NSMutableArray *newOrdering = [NSMutableArray new];
            for (LocalPriority *up in upNext) {
                if ([movingIdentifiers containsObject:up.issue.fullIdentifier]) continue;
                if (up == context) {
                    for (NSString *ii in issueIdentifiers) {
                        LocalPriority *next = lookup[ii];
                        if (!next) {
                            LocalIssue *issue = missingIssues[ii];
                            if (issue) {
                                next = [NSEntityDescription insertNewObjectForEntityForName:@"LocalPriority" inManagedObjectContext:_moc];
                                next.issue = issue;
                                next.user = me;
                            }
                        }
                        if (next) {
                            [newOrdering addObject:next];
                        }
                    }
                }
                [newOrdering addObject:up];
            }
            
            NSInteger j = 0;
            for (LocalPriority *up in newOrdering) {
                up.priority = @((double)j);
                j++;
            }
        } else {
            double priority = start;
            for (NSString *ii in issueIdentifiers) {
                LocalPriority *next = lookup[ii];
                if (!next) {
                    LocalIssue *issue = missingIssues[ii];
                    if (issue) {
                        next = [NSEntityDescription insertNewObjectForEntityForName:@"LocalPriority" inManagedObjectContext:_moc];
                        next.issue = issue;
                        next.user = me;
                    }
                }
                next.priority = @(priority);
                priority += increment;
            }
        }
        
        [_moc save:&err];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil);
            [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidUpdateMyUpNextNotification object:self];
        });
    }];
}

# pragma mark - GitHub notifications handling

- (void)markIssueAsRead:(id)issueIdentifier {
    [_moc performBlock:^{
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"issue.fullIdentifier = %@", issueIdentifier];
        
        LocalNotification *note = [[_moc executeFetchRequest:fetch error:NULL] firstObject];
        if (note.unread) {
            NSString *endpoint = [NSString stringWithFormat:@"/notifications/threads/%@", note.identifier];
            [_serverConnection perform:@"PATCH" on:endpoint body:nil completion:^(id jsonResponse, NSError *error) {
                if (!error) {
                    [_moc performBlock:^{
                        note.unread = NO;
                        [_moc save:NULL];
                    }];
                } else {
                    ErrLog(@"%@", error);
                }
            }];
        }
    }];
}

- (void)markAllIssuesAsReadWithCompletion:(void (^)(NSError *error))completion {
    void (^complete)(NSError *) = ^(NSError *err) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(err);
            });
        }
    };
    
    [_moc performBlock:^{
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"unread = YES"];
        NSArray *notes = [_moc executeFetchRequest:fetch error:NULL];
        
        if ([notes count]) {
            [_serverConnection perform:@"PUT" on:@"/notifications" body:nil completion:^(id jsonResponse, NSError *error) {
                if (!error) {
                    [_moc performBlock:^{
                        for (LocalNotification *note in notes) {
                            note.unread = NO;
                        }
                        [_moc save:NULL];
                        
                        complete(nil);
                    }];
                } else {
                    complete(error);
                }
            }];
        } else {
            complete(nil);
        }
    }];
}

@end

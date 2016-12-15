//
//  DataStore.m
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "DataStoreInternal.h"

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
#import "Billing.h"

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
#import "LocalQuery.h"
#import "LocalReaction.h"
#import "LocalHidden.h"
#import "LocalProject.h"

#import "Issue.h"
#import "IssueComment.h"
#import "IssueIdentifier.h"
#import "Repo.h"
#import "Org.h"
#import "CustomQuery.h"
#import "Reaction.h"
#import "Milestone.h"
#import "Project.h"

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

NSString *const DataStoreDidChangeReposHidingNotification = @"DataStoreDidChangeReposHidingNotification";
NSString *const DataStoreHiddenReposKey = @"DataStoreHiddenReposKey";
NSString *const DataStoreUnhiddenReposKey = @"DataStoreUnhiddenReposKey";

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
NSString *const DataStoreNeedsUpdatedServerNotification = @"DataStoreNeedsUpdatedServerNotification";

NSString *const DataStoreBillingStateDidChangeNotification = @"DataStoreBillingStateDidChangeNotification";

NSString *const DataStoreRateLimitedDidChangeNotification = @"DataStoreRateLimitedDidChangeNotification";
NSString *const DataStoreRateLimitPreviousEndDateKey = @"DataStoreRateLimitPreviousEndDateKey";
NSString *const DataStoreRateLimitUpdatedEndDateKey = @"DataStoreRateLimitUpdatedEndDateKey";

@interface SyncCacheKey : NSObject <NSCopying>

+ (SyncCacheKey *)keyWithEntity:(NSString *)entity identifier:(NSNumber *)identifier;
+ (SyncCacheKey *)keyWithManagedObject:(NSManagedObject *)obj;

@property (nonatomic, readonly) NSString *entity;
@property (nonatomic, readonly) NSNumber *identifier;

@end

@interface ReadOnlyManagedObjectContext : NSManagedObjectContext

@property NSUInteger writeGeneration;

@end

/*
 Change History:
 1: First Version
 2: Server Integration
 3: realartists/shiphub-cocoa#109 Handle PRs in the database
 4: realartists/shiphub-cocoa#76 Support multiple assignees
 5: Milestone and repo hiding (realartists/shiphub-cocoa#157 realartists/shiphub-cocoa#145)
 6: realartists/shiphub-cocoa#217 User.queries needs to be modeled as to-many relationship
 7: realartists/shiphub-cocoa#288 Switch to labels with identifiers
 */
static const NSInteger CurrentLocalModelVersion = 7;

@interface DataStore () <SyncConnectionDelegate> {
    NSLock *_metadataLock;
    
    dispatch_queue_t _needsMetadataQueue;
    NSMutableArray *_needsMetadataItems;
    
    dispatch_queue_t _queryUploadQueue;
    NSMutableSet *_queryUploadProcessing; // only manipulated within _moc.
    NSMutableArray *_needsQuerySyncItems;
    dispatch_queue_t _needsQuerySyncQueue;

    NSString *_purgeVersion;
    
    NSMutableDictionary *_syncCache; // only manipulated within _moc.
    
    NSInteger _initialSyncProgress;
    
    BOOL _sentNetworkActivityBegan;
    double _issueSyncProgress;
    
    dispatch_queue_t _dbq;
    dispatch_queue_t _readMocsQ;
    dispatch_semaphore_t _readSema;
    
    NSUInteger _writeGeneration;
    
    NSTimer *_rateLimitTimer;
}

@property (strong) Auth *auth;
@property (strong) Billing *billing;
@property (strong) ServerConnection *serverConnection;
@property (strong) SyncConnection *syncConnection;
@property (strong) GHNotificationManager *ghNotificationManager;

@property (strong) NSManagedObjectModel *mom;
@property (strong) NSManagedObjectContext *writeMoc;
@property (strong) NSMutableArray<ReadOnlyManagedObjectContext *> *readMocs;
@property (strong) NSPersistentStore *persistentStore;
@property (strong) NSPersistentStoreCoordinator *persistentCoordinator;

@property (readwrite, strong) NSDate *lastUpdated;

@property (readwrite, strong) MetadataStore *metadataStore;

@property (readwrite, strong) NSArray *myQueries;

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
    
    if (_auth.account) {
        NSArray *parts = @[ _auth.account.login, _auth.account.shipHost ];
        [[Defaults defaults] setObject:parts forKey:DefaultsLastUsedAccountKey];
    } else {
        [[Defaults defaults] removeObjectForKey:DefaultsLastUsedAccountKey];
    }
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

- (void)postNotification:(NSString *)notificationName userInfo:(NSDictionary *)userInfo {
    RunOnMain(^{
        if ([self isActive]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
        }
    });
}

+ (Class)serverConnectionClass {
    return [ServerConnection class];
}

+ (Class)syncConnectionClassWithAuth:(Auth *)auth {
    if ([auth.account.shipHost isEqualToString:auth.account.ghHost]) {
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
        
        if (![self openDB]) {
            return nil;
        }
        
        self.billing = [[Billing alloc] initWithDataStore:self];
        
        self.serverConnection = [[[[self class] serverConnectionClass] alloc] initWithAuth:_auth];
        self.syncConnection = [[[[self class] syncConnectionClassWithAuth:_auth] alloc] initWithAuth:_auth];
        self.syncConnection.delegate = self;
        
        [self loadMetadata];
        [self loadQueries];
        [self updateSyncConnectionWithVersions];
        
        _ghNotificationManager = [[GHNotificationManager alloc] initWithDataStore:self];
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
    
    NSString *dbname = @"ship.db";
    
    NSString *basePath = [[[Defaults defaults] stringForKey:DefaultsLocalStoragePathKey] stringByExpandingTildeInPath];
    NSString *path = [basePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/%@", _auth.account.shipHost, _auth.account.shipIdentifier, dbname]];
    
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
    
    if (previousStoreVersion < 7) {
        DebugLog(@"Updating to version %td database from %td. Forcing database re-creation.", CurrentLocalModelVersion, previousStoreVersion);
        forceRecreate = YES;
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
    
    _writeMoc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    _writeMoc.persistentStoreCoordinator = _persistentCoordinator;
    _writeMoc.undoManager = nil; // don't care about undo-ing here, and it costs performance to have an undo manager.
    
    NSUInteger ncpus = [[NSProcessInfo processInfo] processorCount];
    NSMutableArray *readMocs = [NSMutableArray arrayWithCapacity:ncpus];
    for (NSUInteger i = 0; i < ncpus; i++) {
        NSManagedObjectContext *readMoc = [[ReadOnlyManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
        if (&NSPersistentStoreConnectionPoolMaxSizeKey != NULL) {
            readMoc.persistentStoreCoordinator = _persistentCoordinator; // 10.12 / iOS 10
        } else {
            // 10.11 / iOS 9
            NSPersistentStoreCoordinator *pc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_mom];
            [pc addPersistentStoreWithType:NSSQLiteStoreType configuration:@"Default" URL:storeURL options:@{NSReadOnlyPersistentStoreOption : @YES } error:NULL];
            readMoc.persistentStoreCoordinator = pc;
        }
        
        readMoc.undoManager = nil;
        [readMocs addObject:readMoc];
    }
    _readMocs = readMocs;
    _readMocsQ = dispatch_queue_create("DataStore.readMocs", NULL);
    _readSema = dispatch_semaphore_create(_readMocs.count);
    _dbq = dispatch_queue_create("DataStore.dbq", DISPATCH_QUEUE_CONCURRENT);
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mocDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:_writeMoc];
    
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
        [_writeMoc performBlockAndWait:^{
#if !INCOMPLETE
            [self setLatestSequence:0 syncType:@"addressBook"];
            [self setLatestSequence:0 syncType:@"classifications"];
            [self setLatestSequence:0 syncType:@"components"];
            [self setLatestSequence:0 syncType:@"milestones"];
            [self setLatestSequence:0 syncType:@"priorities"];
            [self setLatestSequence:0 syncType:@"states"];
#endif
            [_writeMoc save:NULL];
        }];
    } else if (needsABResync) {
        DebugLog(@"Forcing address book resync");
        [_writeMoc performBlockAndWait:^{
#if !INCOMPLETE
            [self setLatestSequence:0 syncType:@"addressBook"];
#endif
            [_writeMoc save:NULL];
        }];
    }
    
    return YES;
}

- (void)performWrite:(void (^)(NSManagedObjectContext *moc))block {
    NSParameterAssert(block);
    
    dispatch_barrier_async(_dbq, ^{
        [_writeMoc performBlockAndWait:^{
            block(_writeMoc);
        }];
        _writeGeneration++;
    });
}

- (void)performWriteAndWait:(void (^)(NSManagedObjectContext *moc))block {
    NSParameterAssert(block);
    
    dispatch_barrier_sync(_dbq, ^{
        [_writeMoc performBlockAndWait:^{
            block(_writeMoc);
        }];
        _writeGeneration++;
    });
}

- (void)performRead:(void (^)(NSManagedObjectContext *moc))block {
    dispatch_async(_dbq, ^{
        dispatch_semaphore_wait(_readSema, DISPATCH_TIME_FOREVER);
        __block ReadOnlyManagedObjectContext *reader = nil;
        dispatch_sync(_readMocsQ, ^{
            reader = [_readMocs lastObject];
            [_readMocs removeLastObject];
        });
        
        
        [reader performBlockAndWait:^{
            if (reader.writeGeneration != _writeGeneration) {
                [reader reset];
                reader.writeGeneration = _writeGeneration;
            }
            block(reader);
        }];
        
        dispatch_sync(_readMocsQ, ^{
            [_readMocs addObject:reader];
        });
        dispatch_semaphore_signal(_readSema);
    });
}

- (void)migrationRebuildSnapshots:(BOOL)rebuildSnapshots
              rebuildKeywordUsage:(BOOL)rebuildKeywordUsage
                     withProgress:(NSProgress *)progress
                       completion:(dispatch_block_t)completion
{
    NSAssert(rebuildSnapshots || rebuildKeywordUsage, @"Should be rebuilding at least something here");
    
    [self loadMetadata];
    [self performWrite:^(NSManagedObjectContext *moc) {
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
        [moc save:&err];
        if (err) {
            ErrLog(@"Error saving updated snapshots: %@", err);
        }
        
        CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
        DebugLog(@"Completed migration (snapshots:%d keywords:%d) in %.3fs", rebuildSnapshots, rebuildKeywordUsage, (end-start));
        (void)start; (void)end;
        
        [self deactivateThreadLocal];
        
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), completion);
        }
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadMetadata {
    [_writeMoc performBlockAndWait:^{
        self.metadataStore = [[MetadataStore alloc] initWithMOC:_writeMoc billingState:_billing.state];
    }];
}

- (void)updateSyncConnectionWithVersions {
    [self performRead:^(NSManagedObjectContext *moc) {
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalSyncVersion"];
        NSError *err = nil;
        NSArray *results = [moc executeFetchRequest:fetch error:&err];
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

// Must be called on _writeMoc.
// Does not call save:
- (void)updateSyncVersions:(NSDictionary *)versions {
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalSyncVersion"];
    
    NSError *err = nil;
    NSArray *results = [_writeMoc executeFetchRequest:fetchRequest error:&err];
    if (err) {
        ErrLog(@"%@", err);
        return;
    }
    
    LocalSyncVersion *obj = [results firstObject] ?: [NSEntityDescription insertNewObjectForEntityForName:@"LocalSyncVersion" inManagedObjectContext:_writeMoc];
    
    obj.data = [NSJSONSerialization dataWithJSONObject:versions?:@{} options:0 error:NULL];
}

// Must be called on _writeMoc
- (__kindof NSManagedObject *)cachedObjectWithIdentifier:(NSNumber *)identifier entityName:(NSString *)entityName {
    NSEntityDescription *entity = _mom.entitiesByName[entityName];
    id obj = nil;
    if (entity.isAbstract) {
        for (NSEntityDescription *child in entity.subentities) {
            obj = [self cachedObjectWithIdentifier:identifier entityName:child.name];
            if (obj) break;
        }
    } else {
        id key = [SyncCacheKey keyWithEntity:entityName identifier:identifier];
        obj = _syncCache[key];
    }
    return obj;
}

- (id)cacheKeyWithObject:(NSManagedObject *)obj {
    return [SyncCacheKey keyWithManagedObject:obj];
}

// Must be called on _writeMoc
- (__kindof NSManagedObject *)managedObjectWithIdentifier:(NSNumber *)identifier entityName:(NSString *)entityName {
    id obj = [self cachedObjectWithIdentifier:identifier entityName:entityName];
    if (!obj) {
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
        fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", identifier];
        fetch.includesPendingChanges = _syncCache == nil; // If it were pending, we'd already know about it in our cache
        fetch.fetchLimit = 1;
        obj = [[_writeMoc executeFetchRequest:fetch error:NULL] firstObject];
        if (obj) {
            id key = [self cacheKeyWithObject:obj];
            _syncCache[key] = obj;
        }
    }
    return obj;
}

- (NSDictionary<NSNumber *, __kindof NSManagedObject *> *)managedObjectsWithIdentifiers:(NSArray *)identifiers entityName:(NSString *)entityName {
    
    if (identifiers.count == 0) {
        return nil;
    }
    
    NSMutableDictionary *results = [NSMutableDictionary new];
    NSMutableArray *toFetch = [NSMutableArray new];
    for (NSNumber *identifier in identifiers) {
        NSManagedObject *obj = [self cachedObjectWithIdentifier:identifier entityName:entityName];
        if (obj) {
            results[identifier] = obj;
        } else {
            [toFetch addObject:identifier];
        }
    }
    
    if (toFetch.count) {
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
        fetch.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", toFetch];
        fetch.includesPendingChanges = _syncCache == nil; // If it were pending, we'd already know about it in our cache
        NSArray *found = [_writeMoc executeFetchRequest:fetch error:NULL];
        for (id obj in found) {
            NSNumber *identifier = [obj identifier];
            id key = [self cacheKeyWithObject:obj];
            _syncCache[key] = obj;
            results[identifier] = obj;
        }
        NSDictionary *lookup = [NSDictionary lookupWithObjects:found keyPath:@"identifier"];
        [results addEntriesFromDictionary:lookup];
    }
    
    return results;
}

// Must be called on _writeMoc. Does not call save:
- (__kindof NSManagedObject *)insertManagedObjectWithIdentifier:(NSNumber *)identifier entityName:(NSString *)entityName {
    NSManagedObject *obj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:_writeMoc];
    [obj setValue:identifier forKey:@"identifier"];
    NSString *key = [self cacheKeyWithObject:obj];
    _syncCache[key] = obj;
    return obj;
}

// Must be called on _moc.
// Does not call save:
- (void)updateRelationshipsOn:(NSManagedObject *)obj fromSyncDict:(NSDictionary *)syncDict {
    
    NSDictionary *relationships = obj.entity.relationshipsByName;
    
    for (NSString *key in [relationships allKeys]) {
        NSRelationshipDescription *rel = relationships[key];
        BOOL noPopulate = [rel.userInfo[@"noPopulate"] boolValue];
        
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
                        [_writeMoc deleteObject:relObj];
                    }
                }
            }
            
            // find everything in relatedIDs that already exists
            NSDictionary *existingLookup = [self managedObjectsWithIdentifiers:relatedIDs entityName:rel.destinationEntity.name];
            
            id relatedObjs = rel.ordered ? [NSMutableOrderedSet new] : [NSMutableSet new];
            for (NSNumber *relatedID in relatedIDs) {
                NSManagedObject *relObj = existingLookup[relatedID];
                BOOL populate = !noPopulate;
                if (!relObj) {
                    relObj = [self insertManagedObjectWithIdentifier:relatedID entityName:rel.destinationEntity.name];
                    populate = YES;
                }
                NSDictionary *updates = relatedLookup[relatedID];
                if (updates && populate) {
                    [relObj mergeAttributesFromDictionary:updates];
                }
                [relatedObjs addObject:relObj];
            }
            
            [obj setValue:relatedObjs forKey:key onlyIfChanged:YES];
        } else /* rel.toOne */ {
            id related = syncDict[syncDictKey];
            
            if (!related) continue;
            
            NSDictionary *populate = nil;
            id relatedID = related;
            if ([related isKindOfClass:[NSDictionary class]]) {
                populate = related;
                relatedID = populate[@"identifier"];
            } else if (related == [NSNull null]) {
                [obj setValue:nil forKey:key onlyIfChanged:YES];
                relatedID = nil;
            }
            
            if (relatedID != nil) {
                NSManagedObject *relObj = [self managedObjectWithIdentifier:relatedID entityName:rel.destinationEntity.name];
                if (relObj) {
                    [obj setValue:relObj forKey:key onlyIfChanged:YES];
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
                                    if ([jsonType isEqualToString:type]) {
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
                        relObj = [self insertManagedObjectWithIdentifier:relatedID entityName:relName];
                        if (populate) {
                            [relObj mergeAttributesFromDictionary:populate];
                        }
                        [obj setValue:relObj forKey:key];
                    }
                }
            }
        }
    }
}

// Must be called on _moc. Does not call save. Does not update sync version
- (void)writeSyncObjects:(NSArray<SyncEntry *> *)objs {
    
    for (SyncEntry *e in objs) {
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
        NSManagedObject *mObj = [self managedObjectWithIdentifier:identifier entityName:entityName];
        
        if (e.action == SyncEntryActionSet) {
            if (!mObj) {
                mObj = [self insertManagedObjectWithIdentifier:identifier entityName:entityName];
            }
            
            if ([data isKindOfClass:[NSDictionary class]]) {
                [mObj mergeAttributesFromDictionary:data];
                [self updateRelationshipsOn:mObj fromSyncDict:data];
            }
        } else /*e.action == SyncEntryActionDelete*/ {
            if (mObj) {
                [_writeMoc deleteObject:mObj];
            }
        }
    }
}

- (NSDictionary<NSString *, NSSet *> *)identifiersInSyncEntries:(NSArray<SyncEntry *> *)entries {
    NSArray *entriesByEntity = [entries partitionByKeyPath:@"entityName"];
    NSMutableDictionary *identifiers = [NSMutableDictionary new];
    
    void (^note)(NSString *, NSNumber *) = ^(NSString *entityName, NSNumber *identifier) {
        NSMutableSet *s = identifiers[entityName];
        if (!s) {
            identifiers[entityName] = s = [NSMutableSet new];
        }
        [s addObject:identifier];
    };
    
    void (^noteArr)(NSString *, NSArray *) = ^(NSString *entityName, NSArray *arr) {
        NSMutableSet *s = identifiers[entityName];
        if (!s) {
            identifiers[entityName] = s = [NSMutableSet new];
        }
        [s addObjectsFromArray:arr];
    };
    
    for (NSArray *part in entriesByEntity) {
        SyncEntry *r = part[0];
        NSString *type = r.entityName;
        NSString *entityName = [NSString stringWithFormat:@"Local%@", [type PascalCase]];
        NSEntityDescription *entity = _mom.entitiesByName[entityName];
        if (!entity) continue;
        
        for (SyncEntry *e in part) {
            note(entityName, e.data[@"identifier"]);
        }
        
        NSDictionary *relationships = entity.relationshipsByName;
        for (NSString *key in [relationships allKeys]) {
            NSRelationshipDescription *rel = relationships[key];
            
            if ([key isEqualToString:@"labels"]) {
                continue;
            }
            
            NSString *syncDictKey = rel.userInfo[@"jsonKey"];
            if (!syncDictKey) syncDictKey = key;
            
            for (SyncEntry *e in part) {
                if (e.action != SyncEntryActionSet) continue;
                
                if (rel.toMany) {
                    // to many relationships refer by identifiers or by actual populated objects that have identifiers
                    NSArray *related = e.data[syncDictKey];
                    
                    if (!related) {
                        continue;
                    }
                    
                    NSArray *relatedIDs = nil;
                    if ([[related firstObject] isKindOfClass:[NSDictionary class]]) {
                        relatedIDs = [related arrayByMappingObjects:^id(NSDictionary *x) {
                            return x[@"identifier"];
                        }];
                    } else {
                        relatedIDs = related;
                    }
                    if (!relatedIDs) relatedIDs = @[];
                    
                    noteArr(rel.destinationEntity.name, relatedIDs);
                } else {
                    id related = e.data[syncDictKey];
                    
                    if (!related) continue;
                    
                    id relatedID = related;
                    if ([related isKindOfClass:[NSDictionary class]]) {
                        relatedID = related[@"identifier"];
                    } else if (related == [NSNull null]) {
                        relatedID = nil;
                    }

                    if (relatedID) {
                        note(rel.destinationEntity.name, relatedID);
                    }
                }
            }
        }
    }
    
    return identifiers;
}

// must be called on _writeMoc. Does not call save:.
- (void)ensureEntitiesForIdentifiers:(NSDictionary<NSString *, NSSet *> *)identifiers {
    for (NSString *entityName in identifiers) {
        NSSet *idNums = identifiers[entityName];
        
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
        fetch.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", idNums];
        
        NSError *err = nil;
        NSArray *existing = [_writeMoc executeFetchRequest:fetch error:&err];
        if (err) {
            ErrLog(@"%@", err);
            err = nil;
        }
        
        NSDictionary *lookup = [NSDictionary lookupWithObjects:existing keyPath:@"identifier"];
        
        for (NSNumber *identifier in idNums) {
            NSManagedObject *obj = lookup[identifier];
            if (!obj) {
                NSEntityDescription *entity = _mom.entitiesByName[entityName];
                if (!entity.abstract) {
                    obj = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:_writeMoc];
                    [obj setValue:identifier forKey:@"identifier"];
                } else {
                    continue;
                }
            }
            id key = [self cacheKeyWithObject:obj];
            _syncCache[key] = obj;
        }
    }
}

- (void)syncConnection:(SyncConnection *)sync receivedEntries:(NSArray<SyncEntry *> *)entries versions:(NSDictionary *)versions progress:(double)progress
{
    NSDictionary *identifiers = [self identifiersInSyncEntries:entries];
    
    [self performWrite:^(NSManagedObjectContext *moc) {
        _syncCache = [NSMutableDictionary new];
        
        [self ensureEntitiesForIdentifiers:identifiers];
        
        [self writeSyncObjects:entries];
        [self updateSyncVersions:versions];
        
        _syncCache = nil;
        
        NSError *error = nil;
        [moc save:&error];
        if (error) ErrLog("%@", error);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            _issueSyncProgress = progress;
            [self postNotification:DataStoreDidUpdateProgressNotification userInfo:nil];
        });
    }];
}

- (void)syncConnectionWillConnect:(SyncConnection *)sync {
    dispatch_async(dispatch_get_main_queue(), ^{
        _issueSyncProgress = 0.0;
        [self postNotification:DataStoreDidUpdateProgressNotification userInfo:nil];
    });
}

- (void)syncConnectionDidConnect:(SyncConnection *)sync {
    NSDate *lastUpdated = [NSDate date];
    self.lastUpdated = lastUpdated;
    [self performWrite:^(NSManagedObjectContext *moc) {
        NSMutableDictionary *metadata = [[moc.persistentStoreCoordinator metadataForPersistentStore:_persistentStore] mutableCopy];
        metadata[LastUpdated] = lastUpdated;
        [moc.persistentStoreCoordinator setMetadata:metadata forPersistentStore:_persistentStore];
        NSError *err = nil;
        [moc save:&err];
        if (err) {
            ErrLog(@"Error updating metadata: %@", err);
        }
    }];
    dispatch_async(dispatch_get_main_queue(), ^{
        _issueSyncProgress = 1.0;
        [self postNotification:DataStoreDidUpdateProgressNotification userInfo:nil];
    });
}

- (void)syncConnectionDidDisconnect:(SyncConnection *)sync {
    dispatch_async(dispatch_get_main_queue(), ^{
        _issueSyncProgress = 1.0;
        [self postNotification:DataStoreDidUpdateProgressNotification userInfo:nil];
    });
}

- (NSArray *)changedIssueIdentifiers:(NSNotification *)note {
    NSMutableSet *changed = [NSMutableSet new];
    
    [note enumerateModifiedObjects:^(id obj, CoreDataModificationType modType, BOOL *stop) {
        if ([obj isKindOfClass:[LocalIssue class]]) {
            NSString *identifier = [obj fullIdentifier];
            if (identifier) {
                [changed addObject:identifier];
            }
        } else if ([obj isKindOfClass:[LocalEvent class]]
                   || [obj isKindOfClass:[LocalComment class]]
                   || [obj isKindOfClass:[LocalNotification class]])
        {
            NSString *identifier = [[obj issue] fullIdentifier];
            if (identifier) {
                [changed addObject:identifier];
            }
        } else if ([obj isKindOfClass:[LocalReaction class]]) {
            LocalReaction *lr = obj;
            NSString *identifier = lr.issue.fullIdentifier;
            if (!identifier) {
                identifier = lr.comment.issue.fullIdentifier;
            }
            if (identifier) {
                [changed addObject:identifier];
            }
        }
    }];
    
    return changed.count > 0 ? [changed allObjects] : nil;
}

- (void)checkForCustomQueryChanges:(NSNotification *)note {
    __block bool changed = NO;
    [note enumerateModifiedObjects:^(id obj, CoreDataModificationType modType, BOOL *stop) {
        if ([obj isKindOfClass:[LocalQuery class]]) {
            changed = YES;
            *stop = YES;
        }
    }];
    
    if (changed) {
        [self performRead:^(NSManagedObjectContext *moc) {
            self.myQueries = [self _fetchQueries:moc];
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidUpdateMyQueriesNotification object:nil];
            });
        }];
    }
}

- (void)checkForHiddenRepoChanges:(NSNotification *)note {
    NSMutableArray *nowHidden = [NSMutableArray new];
    NSMutableArray *nowUnhidden = [NSMutableArray new];
    
    [note enumerateModifiedObjects:^(id obj, CoreDataModificationType modType, BOOL *stop) {
        if ([obj isKindOfClass:[LocalHidden class]]) {
            LocalHidden *hidden = obj;
            LocalRepo *repo = hidden.repository;
            if (repo && repo.fullName) {
                [modType == CoreDataModificationTypeDeleted ? nowUnhidden : nowHidden addObject:repo.fullName];
            }
        }
    }];
    
    if (nowHidden.count > 0 || nowUnhidden.count > 0) {
        [self postNotification:DataStoreDidChangeReposHidingNotification userInfo:@{ DataStoreHiddenReposKey : nowHidden, DataStoreUnhiddenReposKey : nowUnhidden }];
    }
}

- (void)mocDidChange:(NSNotification *)note {
    //DebugLog(@"%@", note);
    
    if ([MetadataStore changeNotificationContainsMetadata:note]) {
        DebugLog(@"Updating metadata store");
        MetadataStore *store = [[MetadataStore alloc] initWithMOC:_writeMoc billingState:_billing.state];
        self.metadataStore = store;
        dispatch_async(dispatch_get_main_queue(), ^{
            NSDictionary *userInfo = @{ DataStoreMetadataKey : store };
            [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidUpdateMetadataNotification object:self userInfo:userInfo];
        });
    }
    
    [self checkForCustomQueryChanges:note];
    [self checkForHiddenRepoChanges:note];
    
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

- (NSPredicate *)issuesPredicate:(NSPredicate *)basePredicate {
    NSPredicate *extra = nil;
    if (_billing.limited) {
        extra = [NSPredicate predicateWithFormat:@"repository.private = NO AND repository.hidden = nil AND repository.fullName != nil AND pullRequest = NO"];
    } else {
        extra = [NSPredicate predicateWithFormat:@"repository.hidden = nil AND repository.fullName != nil AND pullRequest = NO"];
    }
    
    return [[basePredicate coreDataPredicate] and:extra];
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
    [self performRead:^(NSManagedObjectContext *moc) {
        @try {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
            fetchRequest.predicate = [self issuesPredicate:predicate];
            fetchRequest.relationshipKeyPathsForPrefetching = @[@"assignees.identifier", @"originator.identifier", @"closedBy.identifier", @"labels.name", @"labels.color", @"milestone.identifier", @"repository.identifier", @"notification.unread"];
            fetchRequest.sortDescriptors = sortDescriptors;
            
            NSError *err = nil;
            NSArray *entities = [moc executeFetchRequest:fetchRequest error:&err];
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
        
        RunOnMain(^{
            completion(results, error);
        });
    }];

}

- (void)countIssuesMatchingPredicate:(NSPredicate *)predicate completion:(void (^)(NSUInteger count, NSError *error))completion {
    __block NSUInteger result = 0;
    __block NSError *error = nil;
    [self performRead:^(NSManagedObjectContext *moc) {
        @try {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
            fetchRequest.predicate = [self issuesPredicate:predicate];
            NSError *err = nil;
            result = [moc countForFetchRequest:fetchRequest error:&err];
            
            if (err) {
                ErrLog(@"%@", err);
                result = 0;
            }
        } @catch (id exc) {
            error = [NSError shipErrorWithCode:ShipErrorCodeInvalidQuery];
            ErrLog(@"%@", exc);
        }
        
        RunOnMain(^{
            completion(result, error);
        });
    }];
}

- (void)issueProgressMatchingPredicate:(NSPredicate *)predicate completion:(void (^)(double progress, NSInteger open, NSInteger closed, NSError *error))completion {
    __block double progress = 0;
    __block NSInteger outOpen = 0;
    __block NSInteger outClosed = 0;
    __block NSError *error = nil;
    
    [self performRead:^(NSManagedObjectContext *moc) {
        @try {
            NSError *err = nil;
            
            NSPredicate *pred = [self issuesPredicate:predicate];
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
            fetchRequest.predicate = pred;
            
            NSUInteger total = [moc countForFetchRequest:fetchRequest error:&err];
            
            if (err) {
                ErrLog(@"%@", err);
                progress = -1.0;
            } else {
                fetchRequest.predicate = [pred and:[NSPredicate predicateWithFormat:@"closed = YES"]];
                NSUInteger closed = [moc countForFetchRequest:fetchRequest error:&err];
                
                if (err) {
                    ErrLog(@"%@", err);
                    progress = -1.0;
                }
                
                if (total == 0) {
                    progress = -1.0;
                } else {
                    outOpen = total - closed;
                    outClosed = closed;
                    progress = (double)closed / (double)total;
                }
            }
        } @catch (id exc) {
            error = [NSError shipErrorWithCode:ShipErrorCodeInvalidQuery];
            ErrLog(@"%@", exc);
        }
        
        RunOnMain(^{
            completion(progress, outOpen, outClosed, error);
        });
    }];
}

- (NSPredicate *)predicateForIssueIdentifiers:(NSArray<NSString *> *)issueIdentifiers
{
    return [self predicateForIssueIdentifiers:issueIdentifiers prefix:nil];
}

// Returns a predicate that is the equivalent of fullIdentifier IN {...}
// But because fullIdentifier is a computed property, we can't actually query on that, so need to make a slightly reworded query.
- (NSPredicate *)predicateForIssueIdentifiers:(NSArray<NSString *> *)issueIdentifiers prefix:(NSString *)prefix
{
    if (issueIdentifiers.count == 0) {
        return [NSPredicate predicateWithValue:NO];
    }
    
    NSString *fullNameKeyPath = @"repository.fullName";
    NSString *numberKeyPath = @"number";
    
    // partition issueIdentifiers by repository
    NSMutableDictionary *byRepo = [NSMutableDictionary new];
    for (NSString *issueIdentifier in issueIdentifiers) {
        NSString *key = [issueIdentifier issueRepoFullName];
        NSMutableArray *list = byRepo[key];
        if (!list) {
            list = [NSMutableArray new];
            byRepo[key] = list;
        }
        [list addObject:[issueIdentifier issueNumber]];
    }
    
    if ([prefix length]) {
        fullNameKeyPath = [NSString stringWithFormat:@"%@.repository.fullName", prefix];
        numberKeyPath = [NSString stringWithFormat:@"%@.number", prefix];
    }
    
    NSMutableArray *subp = [NSMutableArray new];
    for (NSString *repoFullName in byRepo) {
        NSArray *issueNumbers = byRepo[repoFullName];
        [subp addObject:[NSPredicate predicateWithFormat:@"%K = %@ AND %K IN %@", fullNameKeyPath, repoFullName, numberKeyPath, issueNumbers]];
    }
    
    if (subp.count == 1) {
        return [subp firstObject];
    } else {
        return [[NSCompoundPredicate alloc] initWithType:NSOrPredicateType subpredicates:subp];
    }
}

- (NSFetchRequest *)fetchRequestForIssueIdentifier:(NSString *)issueIdentifier {
    NSString *repoFullName = [issueIdentifier issueRepoFullName];
    NSNumber *issueNumber = [issueIdentifier issueNumber];
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"repository.fullName = %@ AND number = %@ AND pullRequest = NO", repoFullName, issueNumber];
    
    return fetchRequest;
}

- (void)loadFullIssue:(id)issueIdentifier completion:(void (^)(Issue *issue, NSError *error))completion {
    NSParameterAssert(issueIdentifier);
    
    [self performRead:^(NSManagedObjectContext *moc) {
        NSFetchRequest *fetchRequest = [self fetchRequestForIssueIdentifier:issueIdentifier];
        fetchRequest.relationshipKeyPathsForPrefetching = @[@"events", @"comments", @"labels"];
        
        NSError *err = nil;
        NSArray *entities = [moc executeFetchRequest:fetchRequest error:&err];
        
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
    [self performWrite:^(NSManagedObjectContext *moc) {
        SyncEntry *e = [SyncEntry new];
        e.action = SyncEntryActionSet;
        e.entityName = type;
        e.data = obj;
        
        [self writeSyncObjects:@[e]];
        
        NSError *err = nil;
        [moc save:&err];
        if (err) ErrLog(@"%@", err);
        
        if (completion) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), completion);
        }
    }];
}

#pragma mark - Issue Mutation

- (void)patchIssue:(NSDictionary *)patch issueIdentifier:(id)issueIdentifier completion:(void (^)(Issue *issue, NSError *error))completion
{
    NSParameterAssert(patch);
    NSParameterAssert(issueIdentifier);
    NSParameterAssert(completion);
    
    // PATCH /repos/:owner/:repo/issues/:number
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/%@/issues/%@", [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], [issueIdentifier issueNumber]];
    NSDictionary *headers = @{ @"Accept" : @"application/vnd.github.squirrel-girl-preview+json" };
    
    DebugLog(@"Patching %@: %@", issueIdentifier, patch);
    
    [self.serverConnection perform:@"PATCH" on:endpoint headers:headers body:patch completion:^(id jsonResponse, NSError *error) {
        
        if (!error) {
            id myJSON = [JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]];
            
            DebugLog(@"Patch of %@ succeeded: %@", issueIdentifier, myJSON);
            
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
    NSDictionary *headers = @{ @"Accept" : @"application/vnd.github.squirrel-girl-preview+json" };
    [self.serverConnection perform:@"POST" on:endpoint headers:headers body:issueJSON completion:^(id jsonResponse, NSError *error) {
    
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

- (void)deleteComment:(NSNumber *)commentIdentifier inRepoFullName:(NSString *)repoFullName completion:(void (^)(NSError *error))completion
{
    NSParameterAssert(commentIdentifier);
    NSParameterAssert(repoFullName);
    NSParameterAssert(completion);
    
    // DELETE /repos/:owner/:repo/issues/comments/:commentIdentifier
    
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/issues/comments/%@", repoFullName, commentIdentifier];
    [self.serverConnection perform:@"DELETE" on:endpoint body:nil completion:^(id jsonResponse, NSError *error) {
        if (!error) {
            
            [self performWrite:^(NSManagedObjectContext *moc) {
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalComment"];
                
                fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", commentIdentifier];
                fetch.fetchLimit = 1;
                
                NSError *err = nil;
                LocalComment *lc = [[moc executeFetchRequest:fetch error:&err] firstObject];;
                
                if (err) {
                    ErrLog(@"%@", err);
                }
                
                if (lc) {
                    [moc deleteObject:lc];
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
            
            [self performWrite:^(NSManagedObjectContext *moc) {
                NSFetchRequest *fetch = [self fetchRequestForIssueIdentifier:issueIdentifier];
                
                NSError *err = nil;
                LocalIssue *issue = [[moc executeFetchRequest:fetch error:&err] firstObject];
                
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
                    LocalComment *lc = [[moc executeFetchRequest:fetch2 error:&err] firstObject];
                    if (err) ErrLog(@"%@", err);
                    
                    IssueComment *ic = nil;
                    if (lc) {
                         ic = [[IssueComment alloc] initWithLocalComment:lc metadataStore:self.metadataStore];
                    }
                    
                    err = nil;
                    [moc save:&err];
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

- (void)editComment:(NSNumber *)commentIdentifier body:(NSString *)newCommentBody inRepoFullName:(NSString *)repoFullName completion:(void (^)(IssueComment *comment, NSError *error))completion
{
    NSParameterAssert(commentIdentifier);
    NSParameterAssert(newCommentBody);
    NSParameterAssert(repoFullName);
    NSParameterAssert(completion);
    
    // PATCH /repos/:owner/:repo/issues/comments/:commentIdentifier
    
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/issues/comments/%@", repoFullName, commentIdentifier];
    
    [self.serverConnection perform:@"PATCH" on:endpoint body:@{ @"body" : newCommentBody } completion:^(id jsonResponse, NSError *error)
    {
        if (!error) {
            [self performWrite:^(NSManagedObjectContext *moc) {
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalComment"];
                fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", commentIdentifier];
                fetch.fetchLimit = 1;
                
                NSError *err = nil;
                LocalComment *lc = [[moc executeFetchRequest:fetch error:&err] firstObject];
                if (err) ErrLog(@"%@", err);
                
                id d = [JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]];
                
                IssueComment *ic = nil;
                if (lc) {
                    [lc mergeAttributesFromDictionary:d];
                    ic = [[IssueComment alloc] initWithLocalComment:lc metadataStore:self.metadataStore];
                    err = nil;
                    [moc save:&err];
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

- (void)postIssueReaction:(NSString *)reactionContent inIssue:(id)issueFullIdentifier completion:(void (^)(Reaction *reaction, NSError *error))completion
{
    NSParameterAssert(reactionContent);
    NSParameterAssert(issueFullIdentifier);
    NSParameterAssert(completion);
    
    // POST /repos/:owner/:repo/issues/:number/reactions
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/issues/%@/reactions", [issueFullIdentifier issueRepoFullName], [issueFullIdentifier issueNumber]];
    [self.serverConnection perform:@"POST" on:endpoint headers:@{@"Accept":@"application/vnd.github.squirrel-girl-preview"} body:@{@"content": reactionContent} completion:^(id jsonResponse, NSError *error) {
        void (^fail)(NSError *) = ^(NSError *reason) {
            RunOnMain(^{
                completion(nil, reason);
            });
        };
        
        if (!error) {
            id d = [JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]];
            NSString *identifier = d[@"identifier"];
            
            if (!identifier) {
                fail([NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse]);
                return;
            }
            
            [self performWrite:^(NSManagedObjectContext *moc) {
                NSFetchRequest *fetchIssue = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
                fetchIssue.predicate = [self predicateForIssueIdentifiers:@[issueFullIdentifier]];
                
                NSError *cdErr = nil;
                LocalIssue *issue = [[moc executeFetchRequest:fetchIssue error:&cdErr] firstObject];
                if (cdErr) {
                    ErrLog(@"%@", cdErr);
                    fail(cdErr);
                    return;
                }
                
                NSFetchRequest *reactionFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalReaction"];
                reactionFetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", identifier];
                
                LocalReaction *lr = [[moc executeFetchRequest:reactionFetch error:&cdErr] firstObject];
                
                if (cdErr) {
                    ErrLog(@"%@", cdErr);
                    fail(cdErr);
                    return;
                }
                
                if (lr) {
                    [lr mergeAttributesFromDictionary:d];
                } else {
                    lr = [NSEntityDescription insertNewObjectForEntityForName:@"LocalReaction" inManagedObjectContext:moc];
                    [lr mergeAttributesFromDictionary:d];
                    [self updateRelationshipsOn:lr fromSyncDict:d];
                    [lr setIssue:issue];
                }
                
                [moc save:&cdErr];
                if (cdErr) {
                    ErrLog(@"%@", cdErr);
                    fail(cdErr);
                    return;
                }
                
                Reaction *r = [[Reaction alloc] initWithLocalReaction:lr metadataStore:self.metadataStore];
                
                RunOnMain(^{
                    completion(r, nil);
                });
            }];
        } else {
            fail(error);
        }
    }];
}

- (void)postCommentReaction:(NSString *)reactionContent inRepoFullName:(NSString *)repoFullName inComment:(NSNumber *)commentIdentifier completion:(void (^)(Reaction *reaction, NSError *error))completion
{
    NSParameterAssert(reactionContent);
    NSParameterAssert(commentIdentifier);
    NSParameterAssert(completion);
    
    // POST /repos/:owner/:repo/issues/comments/:id/reactions
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/issues/comments/%@/reactions", repoFullName, commentIdentifier];
    [self.serverConnection perform:@"POST" on:endpoint headers:@{@"Accept":@"application/vnd.github.squirrel-girl-preview"} body:@{@"content": reactionContent} completion:^(id jsonResponse, NSError *error) {
        void (^fail)(NSError *) = ^(NSError *reason) {
            RunOnMain(^{
                completion(nil, reason);
            });
        };
        
        if (!error) {
            id d = [JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]];
            NSString *identifier = d[@"identifier"];
            
            if (!identifier) {
                fail([NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse]);
                return;
            }
            
            [self performWrite:^(NSManagedObjectContext *moc) {
                NSFetchRequest *fetchComment = [NSFetchRequest fetchRequestWithEntityName:@"LocalComment"];
                fetchComment.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", commentIdentifier];
                
                NSError *cdErr = nil;
                LocalComment *comment = [[moc executeFetchRequest:fetchComment error:&cdErr] firstObject];
                if (cdErr) {
                    ErrLog(@"%@", cdErr);
                    fail(cdErr);
                    return;
                }
                
                NSFetchRequest *reactionFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalReaction"];
                reactionFetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", identifier];
                
                LocalReaction *lr = [[moc executeFetchRequest:reactionFetch error:&cdErr] firstObject];
                
                if (cdErr) {
                    ErrLog(@"%@", cdErr);
                    fail(cdErr);
                    return;
                }
                
                if (lr) {
                    [lr mergeAttributesFromDictionary:d];
                } else {
                    lr = [NSEntityDescription insertNewObjectForEntityForName:@"LocalReaction" inManagedObjectContext:moc];
                    [lr mergeAttributesFromDictionary:d];
                    [self updateRelationshipsOn:lr fromSyncDict:d];
                    [lr setComment:comment];
                }
                
                [moc save:&cdErr];
                if (cdErr) {
                    ErrLog(@"%@", cdErr);
                    fail(cdErr);
                    return;
                }
                
                Reaction *r = [[Reaction alloc] initWithLocalReaction:lr metadataStore:self.metadataStore];
                
                RunOnMain(^{
                    completion(r, nil);
                });
            }];
        } else {
            fail(error);
        }
    }];
}

- (void)deleteReaction:(NSNumber *)reactionIdentifier completion:(void (^)(NSError *error))completion
{
    NSParameterAssert(reactionIdentifier);
    NSParameterAssert(completion);
    
    // DELETE /reactions/:id
    NSString *endpoint = [NSString stringWithFormat:@"/reactions/%@", reactionIdentifier];
    
    [self.serverConnection perform:@"DELETE" on:endpoint headers:@{@"Accept":@"application/vnd.github.squirrel-girl-preview"} body:nil completion:^(id jsonResponse, NSError *error) {
        
        void (^fail)(NSError *) = ^(NSError *reason) {
            RunOnMain(^{
                completion(reason);
            });
        };
        
        if (!error) {
            [self performWrite:^(NSManagedObjectContext *moc) {
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalReaction"];
                fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", reactionIdentifier];
                
                NSError *cdErr = nil;
                NSArray *reactions = [moc executeFetchRequest:fetch error:&cdErr];
                if (cdErr) {
                    ErrLog(@"%@", cdErr);
                    fail(cdErr);
                    return;
                }
                
                for (LocalReaction *lr in reactions) {
                    [moc deleteObject:lr];
                }
                
                [moc save:&cdErr];
                if (cdErr) {
                    ErrLog(@"%@", cdErr);
                    fail(cdErr);
                    return;
                }
                
                RunOnMain(^{
                    completion(nil);
                });
            }];
        } else {
            fail(error);
        }
    }];
}

#pragma mark - Metadata Mutation

- (void)addLabel:(NSDictionary *)label
       repoOwner:(NSString *)repoOwner
        repoName:(NSString *)repoName
      completion:(void (^)(NSDictionary *label, NSError *error))completion {
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/%@/labels", repoOwner, repoName];
    [self.serverConnection perform:@"POST" on:endpoint body:label completion:^(id jsonResponse, NSError *error) {
        if (jsonResponse) {
            [self performWrite:^(NSManagedObjectContext *moc) {
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalRepo"];
                fetch.predicate = [NSPredicate predicateWithFormat:@"fullName = %@",
                                   [NSString stringWithFormat:@"%@/%@", repoOwner, repoName]];
                fetch.fetchLimit = 1;
                
                NSError *fetchError;
                NSArray *results = [moc executeFetchRequest:fetch error:&fetchError];
                NSAssert(results != nil, @"Failed to fetch repo: %@", error);
                LocalRepo *localRepo = (LocalRepo *)[results firstObject];
                
                LocalLabel *localLabel = [NSEntityDescription insertNewObjectForEntityForName:@"LocalLabel"
                                                                       inManagedObjectContext:moc];
                localLabel.name = label[@"name"];
                localLabel.color = label[@"color"];
                localLabel.repo = localRepo;
                
                NSError *saveError;
                if ([moc save:&saveError]) {
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

- (void)addMilestone:(NSDictionary *)milestone inRepos:(NSArray<Repo *> *)repos completion:(void (^)(NSArray<Milestone *> *milestones, NSError *error))completion
{
    NSParameterAssert(milestone);
    NSParameterAssert(repos);
    NSParameterAssert(completion);
    NSParameterAssert(repos.count > 0);
    
    NSMutableArray *errors = [NSMutableArray new];
    NSMutableArray *responses = [NSMutableArray new];
    
    dispatch_group_t group = dispatch_group_create();
    for (NSUInteger i = 0; i < repos.count; i++) {
        dispatch_group_enter(group);
        [responses addObject:[NSNull null]];
    }
    
    NSMutableDictionary *contents = [milestone mutableCopy];
    if (contents[@"milestoneDescription"]) {
        contents[@"description"] = contents[@"milestoneDescription"];
        [contents removeObjectForKey:@"milestoneDescription"];
    }
    if (contents[@"dueOn"]) {
        contents[@"due_on"] = [(NSDate *)contents[@"dueOn"] JSONString];
        [contents removeObjectForKey:@"dueOn"];
    }
    
    NSUInteger i = 0;
    for (Repo *repo in repos) {
        // POST /repos/:owner/:repo/milestones
        NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/milestones", repo.fullName];
        NSUInteger j = i;
        i++;
        [self.serverConnection perform:@"POST" on:endpoint body:contents completion:^(id jsonResponse, NSError *error) {
            if (error) {
                ErrLog(@"%@", error);
                [errors addObject:error];
            }
            if (jsonResponse) {
                responses[j] = jsonResponse;
            }
            
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        
        NSMutableArray *successful = [NSMutableArray new];
        NSUInteger k = 0;
        for (id resp in responses) {
            Repo *repo = repos[k];
            if ([resp isKindOfClass:[NSDictionary class]]) {
                NSMutableDictionary *obj = [[JSON parseObject:resp withNameTransformer:[JSON githubToCocoaNameTransformer]] mutableCopy];
                // require GitHub to return at least id, number, and title to continue
                if (!obj[@"identifier"] || !obj[@"number"] || !obj[@"title"]) {
                    ErrLog(@"GitHub returned bogus new milestone dictionary: %@", obj);
                    [errors addObject:[NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse]];
                } else {
                    obj[@"repository"] = repo.identifier;
                    [successful addObject:obj];
                }
            }
            k++;
        }
        
        if ([errors count]) {
            completion(nil, [errors firstObject]);
        }
        
        
        if ([successful count]) {
            NSArray *newIdentifiers = [successful arrayByMappingObjects:^id(id obj) {
                return [obj objectForKey:@"identifier"];
            }];
            void (^fail)(NSError *) = ^(NSError *err) {
                ErrLog(@"%@", err);
                RunOnMain(^{
                    completion(nil, err);
                });
            };
            [self performWrite:^(NSManagedObjectContext *moc) {
                NSFetchRequest *existingFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalMilestone"];
                existingFetch.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", newIdentifiers];
                
                NSError *cdErr = nil;
                NSDictionary *existing = [NSDictionary lookupWithObjects:[moc executeFetchRequest:existingFetch error:&cdErr] keyPath:@"identifier"];
                if (cdErr) {
                    fail(cdErr);
                    return;
                }
                
                NSMutableArray<Milestone *> *resultMilestones = [NSMutableArray new];
                for (NSDictionary *mileDict in successful) {
                    LocalMilestone *lm = existing[mileDict[@"identifier"]];
                    if (!lm) {
                        lm = [NSEntityDescription insertNewObjectForEntityForName:@"LocalMilestone" inManagedObjectContext:moc];
                    }
                    [lm mergeAttributesFromDictionary:mileDict];
                    [self updateRelationshipsOn:lm fromSyncDict:mileDict];
                    
                    Milestone *result = [[Milestone alloc] initWithLocalItem:lm];
                    [resultMilestones addObject:result];
                }
                
                [moc save:&cdErr];
                if (cdErr) {
                    fail(cdErr);
                    return;
                }
                
                RunOnMain(^{
                    completion(resultMilestones, nil);
                });
            }];
        }
    });
}

- (void)addProjectNamed:(NSString *)projName body:(NSString *)projBody inRepo:(Repo *)repo completion:(void (^)(Project *proj, NSError *error))completion
{
    NSParameterAssert(projName);
    NSParameterAssert(repo);
    NSParameterAssert(completion);
    
    NSMutableDictionary *contents = [NSMutableDictionary new];
    contents[@"name"] = projName;
    if ([projBody length]) {
        contents[@"body"] = projBody;
    }
    
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/projects", repo.fullName];
    [self.serverConnection perform:@"POST" on:endpoint headers:@{@"Accept":@"application/vnd.github.inertia-preview+json"} body:contents completion:^(id jsonResponse, NSError *error) {
        if (error) {
            RunOnMain(^{
                completion(nil, error);
            });
        } else {
            [self performWrite:^(NSManagedObjectContext *moc) {
                LocalProject *proj = [NSEntityDescription insertNewObjectForEntityForName:@"LocalProject" inManagedObjectContext:moc];
                NSMutableDictionary *projDict = [[JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]] mutableCopy];
                projDict[@"repository"] = repo.identifier;
                [proj mergeAttributesFromDictionary:projDict];
                [self updateRelationshipsOn:proj fromSyncDict:projDict];
                
                Project *result = [[Project alloc] initWithLocalItem:proj owningRepo:repo];
                NSError *cdErr = nil;
                [moc save:&cdErr];
                if (cdErr) {
                    RunOnMain(^{
                        completion(nil, cdErr);
                    });
                } else {
                    RunOnMain(^{
                        completion(result, nil);
                    });
                }
            }];
        }
    }];
}

- (void)addProjectNamed:(NSString *)projName body:(NSString *)projBody inOrg:(Org *)org completion:(void (^)(Project *proj, NSError *error))completion
{
    NSParameterAssert(projName);
    NSParameterAssert(org);
    NSParameterAssert(completion);
    
    NSMutableDictionary *contents = [NSMutableDictionary new];
    contents[@"name"] = projName;
    if ([projBody length]) {
        contents[@"body"] = projBody;
    }
    
    NSString *endpoint = [NSString stringWithFormat:@"/orgs/%@/projects", org.login];
    [self.serverConnection perform:@"POST" on:endpoint headers:@{@"Accept":@"application/vnd.github.inertia-preview+json"} body:contents completion:^(id jsonResponse, NSError *error) {
        if (error) {
            RunOnMain(^{
                completion(nil, error);
            });
        } else {
            [self performWrite:^(NSManagedObjectContext *moc) {
                LocalProject *proj = [NSEntityDescription insertNewObjectForEntityForName:@"LocalProject" inManagedObjectContext:moc];
                NSMutableDictionary *projDict = [[JSON parseObject:jsonResponse withNameTransformer:[JSON githubToCocoaNameTransformer]] mutableCopy];
                projDict[@"organization"] = org.identifier;
                [proj mergeAttributesFromDictionary:projDict];
                [self updateRelationshipsOn:proj fromSyncDict:projDict];
                
                Project *result = [[Project alloc] initWithLocalItem:proj owningOrg:org];
                NSError *cdErr = nil;
                [moc save:&cdErr];
                if (cdErr) {
                    RunOnMain(^{
                        completion(nil, cdErr);
                    });
                } else {
                    RunOnMain(^{
                        completion(result, nil);
                    });
                }
            }];
        }
    }];
}

- (void)deleteProject:(Project *)proj completion:(void (^)(NSError *error))completion {
    NSParameterAssert(proj);
    NSParameterAssert(completion);
    
    NSString *endpoint = [NSString stringWithFormat:@"/projects/%@", proj.identifier];
    [self.serverConnection perform:@"DELETE" on:endpoint headers:@{@"Accept":@"application/vnd.github.inertia-preview+json"} body:nil completion:^(id jsonResponse, NSError *error) {
        
        if (!error) {
            [self performWrite:^(NSManagedObjectContext *write) {
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalProject"];
                fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", proj.identifier];
                fetch.fetchLimit = 1;
                
                LocalProject *lp = [[write executeFetchRequest:fetch error:NULL] firstObject];
                
                if (lp) {
                    [write deleteObject:lp];
                    [write save:NULL];
                }
                
                RunOnMain(^{
                    completion(nil);
                });
            }];
        } else {
            RunOnMain(^{
                completion(error);
            });
        }
    }];
}

#pragma mark - Milestone and Repo Hiding

- (void)setHidden:(BOOL)hidden forMilestones:(NSArray<Milestone *> *)milestones completion:(void (^)(NSError *error))completion {
    NSParameterAssert(milestones);
    
    [self performWrite:^(NSManagedObjectContext *moc) {
        NSFetchRequest *fetchMilestones = [NSFetchRequest fetchRequestWithEntityName:@"LocalMilestone"];
        fetchMilestones.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", [milestones arrayByMappingObjects:^id(id obj) {
            return [obj identifier];
        }]];
        
        NSArray *localMilestones = [moc executeFetchRequest:fetchMilestones error:NULL];
        
        if (!hidden) {
            NSFetchRequest *fetchHiddens = [NSFetchRequest fetchRequestWithEntityName:@"LocalHidden"];
            fetchHiddens.predicate = [NSPredicate predicateWithFormat:@"milestone IN %@", localMilestones];
            
            NSArray *localHiddens = [moc executeFetchRequest:fetchHiddens error:NULL];
            
            for (LocalHidden *h in localHiddens) {
                [moc deleteObject:h];
            }
        } else {
            for (LocalMilestone *lm in localMilestones) {
                if (lm.hidden == nil) {
                    LocalHidden *h = [NSEntityDescription insertNewObjectForEntityForName:@"LocalHidden" inManagedObjectContext:moc];
                    lm.hidden = h;
                }
            }
        }
        
        [moc save:NULL];
        
        RunOnMain(^{
            if (completion) completion(nil);
        });
    }];
}

- (void)setHidden:(BOOL)hidden forRepos:(NSArray<Repo *> *)repos completion:(void (^)(NSError *error))completion {
    NSParameterAssert(repos);
    
    [self performWrite:^(NSManagedObjectContext *moc) {
        NSFetchRequest *fetchRepos = [NSFetchRequest fetchRequestWithEntityName:@"LocalRepo"];
        fetchRepos.predicate = [NSPredicate predicateWithFormat:@"identifier IN %@", [repos arrayByMappingObjects:^id(id obj) {
            return [obj identifier];
        }]];
        
        NSArray *localRepos = [moc executeFetchRequest:fetchRepos error:NULL];
        
        for (LocalRepo *lr in localRepos) {
            if (hidden) {
                if (!lr.hidden) {
                    LocalHidden *h = [NSEntityDescription insertNewObjectForEntityForName:@"LocalHidden" inManagedObjectContext:moc];
                    lr.hidden = h;
                }
            } else {
                if (lr.hidden) {
                    [moc deleteObject:lr.hidden];
                }
            }
        }
        
        [moc save:NULL];
        
        RunOnMain(^{
            if (completion) completion(nil);
        });
    }];
}


#pragma mark - Time Series

- (void)timeSeriesMatchingPredicate:(NSPredicate *)predicate startDate:(NSDate *)startDate endDate:(NSDate *)endDate completion:(void (^)(TimeSeries *series, NSError *error))completion {
    [self performRead:^(NSManagedObjectContext *moc) {
        NSError *error = nil;
        @try {
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
            fetchRequest.predicate = [TimeSeries timeSeriesPredicateWithPredicate:[self issuesPredicate:predicate] startDate:startDate endDate:endDate];
            fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]];
            
            NSError *err = nil;
            NSArray *entities = [moc executeFetchRequest:fetchRequest error:&err];
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
    
    [self performWrite:^(NSManagedObjectContext *moc) {
        __block NSError *err = nil;
        
        dispatch_block_t complete = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(err);
            });
        };
        
        NSFetchRequest *meRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalUser"];
        meRequest.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", [[User me] identifier]];
        meRequest.fetchLimit = 1;
        
        LocalUser *me = [[moc executeFetchRequest:meRequest error:&err] firstObject];
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
        existingRequest.predicate = [mePredicate and:[self predicateForIssueIdentifiers:issueIdentifiers prefix:@"issue"]];
        
        NSDictionary *existing = [NSDictionary lookupWithObjects:[moc executeFetchRequest:existingRequest error:&err] keyPath:@"issue.fullIdentifier"];
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
        
        NSNumber *minMax = [[[moc executeFetchRequest:minMaxRequest error:&err] firstObject] objectForKey:@"priority"];
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
        issuesFetch.predicate = [self predicateForIssueIdentifiers:[neededIssueIdentifiers allObjects]];
        NSDictionary *missingIssues = [NSDictionary lookupWithObjects:[moc executeFetchRequest:issuesFetch error:&err] keyPath:@"fullIdentifier"];
        
        double priority = start;
        for (NSString *issueIdentifier in issueIdentifiers) {
            LocalPriority *mObj = existing[issueIdentifier];
            if (!mObj) {
                LocalIssue *issue = missingIssues[issueIdentifier];
                if (issue) {
                    mObj = [NSEntityDescription insertNewObjectForEntityForName:@"LocalPriority" inManagedObjectContext:moc];
                    mObj.user = me;
                    mObj.issue = issue;
                }
            }
            mObj.priority = @(priority);
            priority += increment;
        }
        
        [moc save:&err];
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
    
    [self performWrite:^(NSManagedObjectContext *moc) {
        __block NSError *err = nil;
        
        dispatch_block_t complete = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(err);
            });
        };
        
        User *me = [User me];
        
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalPriority"];
        fetch.predicate = [[NSPredicate predicateWithFormat:@"user.identifier = %@", me.identifier] and:[self predicateForIssueIdentifiers:issueIdentifiers prefix:@"issue"]];
        
        [moc batchDeleteEntitiesWithRequest:fetch error:&err];
        if (err) {
            ErrLog(@"%@", err);
            complete();
            return;
        }
        
        [moc save:&err];
        
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
    
    [self performWrite:^(NSManagedObjectContext *moc) {
        __block NSError *err = nil;
        
        dispatch_block_t complete = ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(err);
            });
        };
        
        NSFetchRequest *meRequest = [NSFetchRequest fetchRequestWithEntityName:@"LocalUser"];
        meRequest.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", [[User me] identifier]];
        meRequest.fetchLimit = 1;
        
        LocalUser *me = [[moc executeFetchRequest:meRequest error:&err] firstObject];
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
        
        NSArray *upNext = [moc executeFetchRequest:fetch error:&err];
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
        issuesFetch.predicate = [self predicateForIssueIdentifiers:[neededIssueIdentifiers allObjects]];
        NSDictionary *missingIssues = [NSDictionary lookupWithObjects:[moc executeFetchRequest:issuesFetch error:&err] keyPath:@"fullIdentifier"];
        
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
                                next = [NSEntityDescription insertNewObjectForEntityForName:@"LocalPriority" inManagedObjectContext:moc];
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
                        next = [NSEntityDescription insertNewObjectForEntityForName:@"LocalPriority" inManagedObjectContext:moc];
                        next.issue = issue;
                        next.user = me;
                    }
                }
                next.priority = @(priority);
                priority += increment;
            }
        }
        
        [moc save:&err];
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
    [self performRead:^(NSManagedObjectContext *read) {
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
        fetch.predicate = [self predicateForIssueIdentifiers:@[issueIdentifier] prefix:@"issue"];
        
        LocalNotification *note = [[read executeFetchRequest:fetch error:NULL] firstObject];
        NSManagedObjectID *noteID = [note objectID];
        
        if (note.unread) {
            NSString *endpoint = [NSString stringWithFormat:@"/notifications/threads/%@", note.identifier];
            [_serverConnection perform:@"PATCH" on:endpoint body:nil completion:^(id jsonResponse, NSError *error) {
                if (!error) {
                    [self performWrite:^(NSManagedObjectContext *write) {
                        LocalNotification *writeNote = [write existingObjectWithID:noteID error:NULL];
                        if (writeNote) {
                            writeNote.unread = NO;
                            [write save:NULL];
                        }
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
    
    [self performRead:^(NSManagedObjectContext *read) {
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"unread = YES"];
        NSArray *notes = [read executeFetchRequest:fetch error:NULL];
        NSArray *noteIDs = [notes arrayByMappingObjects:^id(id obj) {
            return [obj objectID];
        }];
        
        if ([notes count]) {
            [_serverConnection perform:@"PUT" on:@"/notifications" body:@{} completion:^(id jsonResponse, NSError *error) {
                if (!error) {
                    [self performWrite:^(NSManagedObjectContext *write) {
                        NSFetchRequest *wrFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
                        wrFetch.predicate = [NSPredicate predicateWithFormat:@"SELF IN %@", noteIDs];
                        NSArray *wrNotes = [write executeFetchRequest:wrFetch error:NULL];
                        for (LocalNotification *note in wrNotes) {
                            note.unread = NO;
                        }
                        [write save:NULL];
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

#pragma mark - Queries

// used only by init. blocks.
- (void)loadQueries {
    [_writeMoc performBlockAndWait:^{
        self.myQueries = [self _fetchQueries:_writeMoc];
    }];
}

// must be called on _moc queue.
- (NSArray *)_fetchQueries:(NSManagedObjectContext *)moc {
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalQuery"];
    NSArray *queries = [moc executeFetchRequest:fetch error:NULL];
    
    return [queries arrayByMappingObjects:^id(id obj) {
        return [[CustomQuery alloc] initWithLocalItem:obj];
    }];
}

- (void)saveQuery:(CustomQuery *)query completion:(void (^)(NSArray *myQueries))completion {
    NSParameterAssert(query);
    NSParameterAssert(query.identifier);
    
    [self performWrite:^(NSManagedObjectContext *moc) {
        NSFetchRequest *meFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalUser"];
        meFetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", [[User me] identifier]];
        
        LocalUser *me = [[moc executeFetchRequest:meFetch error:NULL] firstObject];
        if (!me) {
            ErrLog(@"Missing me");
            return;
        }
        
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalQuery"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"author = %@ AND (identifier = %@ OR title =[cd] %@)", me, query.identifier, query.title];
        
        NSArray *queries = [moc executeFetchRequest:fetch error:NULL];
        
        if ([queries count]) {
            for (LocalQuery *q in queries) {
                if ([[q title] compare:query.title options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch] == NSOrderedSame
                    || [[q identifier] isEqualToString:[query identifier]])
                {
                    [q mergeAttributesFromDictionary:[query dictionaryRepresentation]];
                    q.author = me;
                }
            }
        } else {
            LocalQuery *q = [NSEntityDescription insertNewObjectForEntityForName:@"LocalQuery" inManagedObjectContext:moc];
            [q mergeAttributesFromDictionary:[query dictionaryRepresentation]];
            q.author = me;
        }
        
        NSArray *myQueries = [self _fetchQueries:moc];
        
        NSError *error = nil;
        [moc save:&error];
        
        if (error) {
            ErrLog(@"%@", error);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.myQueries = myQueries;
            if (completion) {
                completion(myQueries);
            }
        });
    }];
}

- (void)deleteQuery:(CustomQuery *)query completion:(void (^)(NSArray *myQueries))completion {
    NSParameterAssert(query);
    NSParameterAssert(query.identifier);
    
    [self performWrite:^(NSManagedObjectContext *moc) {
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalQuery"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"identifier = %@", query.identifier];
        
        for (LocalQuery *q in [moc executeFetchRequest:fetch error:NULL]) {
            [moc deleteObject:q];
        }
        
        NSArray *myQueries = [self _fetchQueries:moc];
        
        NSError *error = nil;
        [moc save:&error];
        
        if (error) {
            ErrLog(@"%@", error);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.myQueries = myQueries;
            if (completion) {
                completion(myQueries);
            }
        });
    }];
}

#pragma mark - The Purge

- (BOOL)syncConnection:(SyncConnection *)connection didReceivePurgeIdentifier:(NSString *)purgeIdentifier {
    if (!purgeIdentifier) {
        return NO; // purge not happening
    }
    
    NSPersistentStore *store = [_persistentCoordinator.persistentStores firstObject];
    NSDictionary *currentMetadata = [_persistentCoordinator metadataForPersistentStore:store];
    NSAssert(currentMetadata, @"Expect to have some current metadata");
    
    NSString *currentPurge = currentMetadata[PurgeVersion];
    if (!currentPurge) {
        DebugLog(@"Updating NULL purge identifier to %@", purgeIdentifier);
        [self performWrite:^(NSManagedObjectContext *moc) {
            NSMutableDictionary *newMetadata = [currentMetadata mutableCopy];
            newMetadata[PurgeVersion] = purgeIdentifier;
            [_persistentCoordinator setMetadata:newMetadata forPersistentStore:store];
            [moc save:NULL];
        }];
    } else if (![currentPurge isEqualToString:purgeIdentifier]) {
        DebugLog(@"Purge identifier changed from %@ to %@. Must purge database :(", currentPurge, purgeIdentifier);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreWillPurgeNotification object:self];
        });
        dispatch_async(_needsMetadataQueue, ^{
            [_needsMetadataItems removeAllObjects];
        });
        [self performWrite:^(NSManagedObjectContext *moc) {
            NSMutableDictionary *newMetadata = [currentMetadata mutableCopy];
            newMetadata[PurgeVersion] = purgeIdentifier;
            [_persistentCoordinator setMetadata:newMetadata forPersistentStore:store];
            [moc purge]; // purge will call save: to persist the new metadata
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self loadMetadata];
                [self loadQueries];
                [self updateSyncConnectionWithVersions];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreDidPurgeNotification object:self];
                });
            });
        }];
        
        return YES; // purge is happening
    }
    
    return NO; // did not purge
}

#pragma mark - SyncConnection software update

- (void)syncConnectionRequiresSoftwareUpdate:(SyncConnection *)sync {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DataStoreNeedsMandatorySoftwareUpdateNotification object:self];
    });
}

- (void)syncConnectionRequiresUpdatedServer:(SyncConnection *)sync {
    [self postNotification:DataStoreNeedsUpdatedServerNotification userInfo:nil];
}

#pragma mark - SyncConnection billing update

- (void)syncConnection:(SyncConnection *)sync didReceiveBillingUpdate:(NSDictionary *)update {
    [_billing updateWithRecord:update];
}

#pragma mark - SyncConnection rate limit

- (void)syncConnection:(SyncConnection *)sync didReceiveRateLimit:(NSDate *)limitedUntil {
    RunOnMain(^{
        NSDate *prev = _rateLimitedUntil;
        NSDate *next = limitedUntil;
        if ([next timeIntervalSinceNow] < 1.0) {
            next = nil;
        }
        if ((prev && !next) || (!prev && next) || [prev compare:next] == NSOrderedAscending) {
            _rateLimitedUntil = next;
            [_rateLimitTimer invalidate];
            _rateLimitTimer = nil;
            if (next) {
                _rateLimitTimer = [NSTimer scheduledTimerWithTimeInterval:[next timeIntervalSinceNow] weakTarget:self selector:@selector(rateLimitLifted:) userInfo:prev repeats:NO];
            }
            
            NSMutableDictionary *noteInfo = [NSMutableDictionary new];
            if (prev) noteInfo[DataStoreRateLimitPreviousEndDateKey] = prev;
            if (next) noteInfo[DataStoreRateLimitUpdatedEndDateKey] = next;
            
            [self postNotification:DataStoreRateLimitedDidChangeNotification userInfo:noteInfo];
        }
    });
}

- (void)rateLimitLifted:(NSTimer *)timer {
    _rateLimitedUntil = nil;
    _rateLimitTimer = nil;
    NSDate *prev = timer.userInfo;
    NSMutableDictionary *noteInfo = [NSMutableDictionary new];
    if (prev) noteInfo[DataStoreRateLimitPreviousEndDateKey] = prev;
    
    [self postNotification:DataStoreRateLimitedDidChangeNotification userInfo:noteInfo];
}

@end

@implementation SyncCacheKey {
    NSUInteger _hash;
}

+ (SyncCacheKey *)keyWithEntity:(NSString *)entity identifier:(NSNumber *)identifier {
    SyncCacheKey *key = [SyncCacheKey new];
    key->_entity = entity;
    key->_identifier = identifier;
    key->_hash = [identifier hash] + [entity hash];
    return key;
}

+ (SyncCacheKey *)keyWithManagedObject:(NSManagedObject *)obj {
    return [SyncCacheKey keyWithEntity:obj.entity.name identifier:[(id)obj identifier]];
}

- (id)copyWithZone:(nullable NSZone *)zone {
    return self;
}

- (NSUInteger)hash {
    return _hash;
}

- (BOOL)isEqual:(id)object {
    SyncCacheKey *other = object;
    if (_hash != other->_hash) return NO;
    return _identifier.longLongValue == other->_identifier.longLongValue
        && [_entity isEqualToString:other->_entity];
}

@end

@implementation ReadOnlyManagedObjectContext

- (BOOL)save:(NSError * _Nullable __autoreleasing *)error {
    ErrLog(@"Illegal Attempt to write to ReadOnlyManagedObjectContext");
    abort();
    return NO;
}

- (void)deleteObject:(NSManagedObject *)object {
    ErrLog(@"Illegal Attempt to write to ReadOnlyManagedObjectContext");
    abort();
}

@end

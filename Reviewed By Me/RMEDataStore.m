//
//  RMEDataStore.m
//  ShipHub
//
//  Created by James Howard on 8/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEDataStore.h"

#import "Analytics.h"
#import "Auth.h"
#import "Extras.h"
#import "Issue.h"
#import "IssueIdentifier.h"
#import "PRComment.h"
#import "ServerConnection.h"
#import "RMEPRLoader.h"
#import "RMEDataModelHistoryItem.h"

NSString *const RMEDataStoreCannotOpenDatabaseNotification = @"RMEDataStoreCannotOpenDatabaseNotification";

/*
 Change History:
 1: First Version
*/
static const NSInteger CurrentModelVersion = 1;

@interface RMEDataStore ()

@property (strong) NSManagedObjectModel *mom;
@property (strong) NSManagedObjectContext *moc;
@property (strong) NSPersistentStore *persistentStore;
@property (strong) NSPersistentStoreCoordinator *persistentCoordinator;

@end

@implementation RMEDataStore

- (id)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        _auth = auth;
        
        if (![self openDB]) {
            return nil;
        }
    }
    return self;
}

+ (instancetype)storeWithAuth:(Auth *)auth {
    return [[self alloc] initWithAuth:auth];
}

static RMEDataStore *sActiveStore = nil;

+ (RMEDataStore *)activeStore {
    RMEDataStore *threadLocalStore = [[NSThread currentThread] threadDictionary][@"ActiveDataStore"];
    if (threadLocalStore) {
        return threadLocalStore;
    }
    return sActiveStore;
}

- (void)activate {
    dispatch_assert_current_queue(dispatch_get_main_queue());
    
    sActiveStore = self;
    
    if (_auth.account) {
        NSArray *parts = @[ _auth.account.login, _auth.account.shipHost ];
        [[Defaults defaults] setObject:parts forKey:DefaultsLastUsedAccountKey];
    } else {
        [[Defaults defaults] removeObjectForKey:DefaultsLastUsedAccountKey];
    }
    [[Defaults defaults] synchronize];
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
    dispatch_assert_current_queue(dispatch_get_main_queue());
    
    if (self == sActiveStore) {
        sActiveStore = nil;
    }
}

- (BOOL)isActive {
    return sActiveStore == self;
}

- (NSString *)_dbPath {
    NSAssert(_auth.account.ghIdentifier, @"Must have a user identifier to open the database");
    
    NSString *dbname = @"ReviewedByMe.db";
    
    NSString *basePath = [[[Defaults defaults] stringForKey:DefaultsLocalStoragePathKey] stringByExpandingTildeInPath];
    NSString *path = [basePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@/%@", _auth.account.ghHost, _auth.account.ghIdentifier, dbname]];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
    return path;
}

- (BOOL)openDB {
    return [self openDBForceRecreate:NO];
}

static NSString *const StoreVersion = @"DataStoreVersion";

- (BOOL)openDBForceRecreate:(BOOL)forceRecreate {
    NSString *filename = [self _dbPath];
    
    DebugLog(@"Opening DB at path: %@", filename);
    
    NSURL *momURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"RMEDataModel" withExtension:@"momd"];
    _mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:momURL];
    NSAssert(_mom, @"Must load mom from %@", momURL);
    
    _persistentCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_mom];
    NSAssert(_persistentCoordinator, @"Must load coordinator");
    NSURL *storeURL = [NSURL fileURLWithPath:filename];
    NSError *err = nil;
    
    // Determine if a migration is needed
    NSDictionary *sourceMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:storeURL options:nil error:&err];
    
    NSInteger previousStoreVersion = sourceMetadata ? [sourceMetadata[StoreVersion] integerValue] : CurrentModelVersion;
    
    if (previousStoreVersion > CurrentModelVersion) {
        ErrLog(@"Database has version %td, which is newer than client version %td.", previousStoreVersion, CurrentModelVersion);
        [[NSNotificationCenter defaultCenter] postNotificationName:RMEDataStoreCannotOpenDatabaseNotification object:nil /*nil because we're about to fail to init*/ userInfo:nil];
        return NO;
    }
    
    BOOL needsHeavyweightMigration = NO;
    
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @(!needsHeavyweightMigration) };
    
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
    storeMetadata[StoreVersion] = @(CurrentModelVersion);
    [_persistentCoordinator setMetadata:storeMetadata forPersistentStore:store];
    
    _moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    _moc.persistentStoreCoordinator = _persistentCoordinator;
    _moc.undoManager = nil; // don't care about undo-ing here, and it costs performance to have an undo manager.
    
    return YES;
}

- (void)loadFullIssue:(id)issueIdentifier completion:(void (^)(Issue *issue, NSError *error))completion
{
    RMEPRLoader *loader = [[RMEPRLoader alloc] initWithIssueIdentifier:issueIdentifier auth:self.auth queue:dispatch_get_main_queue()];
    loader.completion = completion;
    [loader start];
}

- (void)storeLastViewedHeadSha:(NSString *)headSha forPullRequestIdentifier:(NSString *)issueIdentifier pullRequestTitle:(NSString *)title completion:(void (^)(NSString *lastSha, NSError *error))completion
{
    [_moc performBlock:^{
        RMEDataModelHistoryItem *item = nil;
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"RMEDataModelHistoryItem"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"issueIdentifier = %@", issueIdentifier];
        
        item = [[_moc executeFetchRequest:fetch error:NULL] firstObject];
        
        if (!item) {
            item = [NSEntityDescription insertNewObjectForEntityForName:@"RMEDataModelHistoryItem" inManagedObjectContext:_moc];
            item.issueIdentifier = issueIdentifier;
        }
        
        item.issueTitle = title;
        item.lastViewedAt = [NSDate date];
        
        NSString *previousSha = item.lastViewedSha;
        
        item.lastViewedSha = headSha;
        
        [_moc save:NULL];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            completion(previousSha, nil);
        });
    }];
}

@end

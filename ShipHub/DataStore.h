//
//  DataStore.h
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Auth;

@interface DataStore : NSObject

+ (instancetype)storeWithAuth:(Auth *)auth;

@property (strong, readonly) Auth *auth;

+ (instancetype)activeStore;
- (void)activate;
- (void)deactivate;

@property (nonatomic, readonly, getter=isActive) BOOL active; // YES if self == [DataStore activeStore].
@property (nonatomic, readonly, getter=isValid) BOOL valid; // YES if authenticated and not currently performing migration.

@property (nonatomic, readonly, getter=isOffline) BOOL offline;

@property (nonatomic, readonly, getter=isMigrating) BOOL migrating;
@property (nonatomic, readonly, getter=isPerformingInitialSync) BOOL performingInitialSync;

@end

extern NSString *const DataStoreWillBeginMigrationNotification;
extern NSString *const DataStoreDidEndMigrationNotification;

extern NSString *const DataStoreActiveDidChangeNotification; // Sent when the active data store changes

extern NSString *const DataStoreDidUpdateMetadataNotification;
extern NSString *const DataStoreMetadataKey;

extern NSString *const DataStoreDidUpdateProblemsNotification;
extern NSString *const DataStoreUpdatedProblemsKey; // => NSArray of Issue IDs updated
extern NSString *const DataStoreUpdateProblemSourceKey; // => DataStoreProblemUpdateSource

extern NSString *const DataStoreDidUpdateOutboxNotification;
extern NSString *const DataStoreOutboxResolvedProblemIdentifiersKey; // => NSDictionary mapping old identifier (<0) to new identifier (>0)
extern NSString *const DataStoreMigrationProgressKey; // => NSProgress

extern NSString *const DataStoreDidUpdateMyQueriesNotification; // Sent when myQueries changes

extern NSString *const DataStoreWillPurgeNotification;
extern NSString *const DataStoreDidPurgeNotification;

extern NSString *const DataStoreCannotOpenDatabaseNotification; // Sent when the client version is too old to open the database.

extern NSString *const DataStoreWillBeginInitialMetadataSync;
extern NSString *const DataStoreDidEndInitialMetadataSync;

extern NSString *const DataStoreWillBeginNetworkActivityNotification;
extern NSString *const DataStoreDidEndNetworkActivityNotification;
extern NSString *const DataStoreDidUpdateProgressNotification;

extern NSString *const DataStoreNeedsMandatorySoftwareUpdateNotification;

typedef NS_ENUM (NSInteger, DataStoreProblemUpdateSource) {
    DataStoreProblemUpdateSourceSync = 1,
    DataStoreProblemUpdateSourceSave,
};

@interface DataStore (Testing)

+ (Class)serverConnectionClass;
+ (Class)syncConnectionClass;

@end

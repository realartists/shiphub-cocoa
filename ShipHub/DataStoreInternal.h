//
//  DataStoreInternal.h
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "DataStore.h"

#import <CoreData/CoreData.h>

@interface DataStore (Internal)

@property (readonly) Auth *auth;
@property (readonly) NSManagedObjectModel *mom;

- (void)performWrite:(void (^)(NSManagedObjectContext *moc))block;
- (void)performWriteAndWait:(void (^)(NSManagedObjectContext *moc))block;
- (void)performRead:(void (^)(NSManagedObjectContext *moc))block;

- (void)postNotification:(NSString *)notificationName userInfo:(NSDictionary *)userInfo;

@end

@interface EntityCacheKey : NSObject <NSCopying>

+ (EntityCacheKey *)keyWithEntity:(NSString *)entity identifier:(NSNumber *)identifier;
+ (EntityCacheKey *)keyWithManagedObject:(NSManagedObject *)obj;

@property (nonatomic, readonly) NSString *entity;
@property (nonatomic, readonly) NSNumber *identifier;

@end

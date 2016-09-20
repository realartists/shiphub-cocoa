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
@property (readonly) NSManagedObjectContext *moc;
@property (readonly) NSManagedObjectModel *mom;

- (void)postNotification:(NSString *)notificationName userInfo:(NSDictionary *)userInfo;

@end

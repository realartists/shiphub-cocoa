//
//  MetadataStoreInternal.h
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "MetadataStore.h"

@class LocalUser;

@interface MetadataStore (Internal)

+ (BOOL)changeNotificationContainsMetadata:(NSNotification *)mocNote;

// Read data out of ctx and store in immutable data objects accessible from any thread.
- (instancetype)initWithMOC:(NSManagedObjectContext *)ctx;

- (User *)userWithLocalUser:(LocalUser *)lu;

@end

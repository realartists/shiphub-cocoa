//
//  LocalSyncVersion+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 5/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalSyncVersion.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalSyncVersion (CoreDataProperties)

@property (nullable, nonatomic, retain) NSData *data;

@end

NS_ASSUME_NONNULL_END

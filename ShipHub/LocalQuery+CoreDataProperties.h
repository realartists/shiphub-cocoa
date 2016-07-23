//
//  LocalQuery+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 7/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalQuery.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalQuery (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *predicate;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSString *identifier;
@property (nullable, nonatomic, retain) LocalUser *author;

@end

NS_ASSUME_NONNULL_END

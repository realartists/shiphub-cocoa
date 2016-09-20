//
//  LocalBilling+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalBilling.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalBilling (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *billingState;
@property (nullable, nonatomic, retain) NSDate *endDate;

@end

NS_ASSUME_NONNULL_END

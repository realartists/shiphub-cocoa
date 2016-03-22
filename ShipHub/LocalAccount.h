//
//  LocalAccount.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#import "LocalMetadata.h"

@class LocalRepo;

NS_ASSUME_NONNULL_BEGIN

@interface LocalAccount : NSManagedObject <LocalMetadata>

// Insert code here to declare functionality of your managed object subclass

@end

NS_ASSUME_NONNULL_END

#import "LocalAccount+CoreDataProperties.h"

//
//  LocalIssue.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class LocalMilestone, LocalRepo;

NS_ASSUME_NONNULL_BEGIN

@interface LocalIssue : NSManagedObject

@property (nonatomic, readonly, nullable) NSString *fullIdentifier;

// Sets shipLocalUpdatedAt to date iff date is newer than shipLocalUpdatedAt.
- (void)setShipLocalUpdatedAtIfNewer:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END

#import "LocalIssue+CoreDataProperties.h"

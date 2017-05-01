//
//  LocalEvent.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class LocalMilestone;

NS_ASSUME_NONNULL_BEGIN

@interface LocalEvent : NSManagedObject

- (id)computeCommitIdForProperty:(NSString *)propertyKey inDictionary:(NSDictionary *)d;

@end

NS_ASSUME_NONNULL_END

#import "LocalEvent+CoreDataProperties.h"

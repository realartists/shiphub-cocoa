//
//  LocalReaction.h
//  ShipHub
//
//  Created by James Howard on 8/3/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class LocalComment, LocalIssue, LocalUser;

NS_ASSUME_NONNULL_BEGIN

@interface LocalReaction : NSManagedObject

// Insert code here to declare functionality of your managed object subclass

@end

NS_ASSUME_NONNULL_END

#import "LocalReaction+CoreDataProperties.h"

//
//  LocalNotification+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 7/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalNotification.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocalNotification (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *commentIdentifier;
@property (nullable, nonatomic, retain) NSString *reason;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSDate *updatedAt;
@property (nullable, nonatomic, retain) NSDate *lastReadAt;
@property (nullable, nonatomic, retain) NSNumber *unread;
@property (nullable, nonatomic, retain) NSString *issueFullIdentifier;
@property (nullable, nonatomic, retain) LocalIssue *issue;

@end

NS_ASSUME_NONNULL_END

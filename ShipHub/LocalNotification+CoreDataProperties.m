//
//  LocalNotification+CoreDataProperties.m
//  ShipHub
//
//  Created by James Howard on 7/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalNotification+CoreDataProperties.h"

@implementation LocalNotification (CoreDataProperties)

@dynamic commentIdentifier;
@dynamic reason;
@dynamic identifier;
@dynamic updatedAt;
@dynamic lastReadAt;
@dynamic unread;
@dynamic issueFullIdentifier;
@dynamic issue;

@end

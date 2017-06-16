//
//  LocalProtectedBranch.h
//  ShipHub
//
//  Created by James Howard on 6/15/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@class LocalRepo;

@interface LocalProtectedBranch : NSManagedObject

@property (nonatomic, strong) NSNumber *identifier;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSData *rawJSON;
@property (nonatomic, strong) LocalRepo *repository;

@end

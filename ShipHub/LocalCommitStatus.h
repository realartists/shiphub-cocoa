//
//  LocalCommitStatus.h
//  ShipHub
//
//  Created by James Howard on 4/27/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@class LocalAccount, LocalRepo;

@interface LocalCommitStatus : NSManagedObject

@property (nonatomic, strong) NSNumber *identifier;
@property (nonatomic, strong) NSString *reference;
@property (nonatomic, strong) NSString *state;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;
@property (nonatomic, strong) NSString *targetUrl;
@property (nonatomic, strong) NSString *statusDescription;
@property (nonatomic, strong) NSString *context;

@property (nonatomic, strong) LocalAccount *creator;
@property (nonatomic, strong) LocalRepo *repository;

@end

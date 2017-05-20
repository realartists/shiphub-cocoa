//
//  LocalCommitComment.h
//  ShipHub
//
//  Created by James Howard on 5/19/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@class LocalRepo, LocalAccount, LocalReaction;

@interface LocalCommitComment : NSManagedObject

@property (nonatomic, strong) NSNumber *identifier;
@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSString *commitId;
@property (nonatomic, strong) NSNumber *line;
@property (nonatomic, strong) NSNumber *path;
@property (nonatomic, strong) NSNumber *position;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *updatedAt;

@property (nonatomic, strong) LocalRepo *repository;
@property (nonatomic, strong) LocalAccount *user;

@property (nonatomic, strong) NSSet<LocalReaction *> *reactions;

@end

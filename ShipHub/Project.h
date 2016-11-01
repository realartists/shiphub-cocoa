//
//  Project.h
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MetadataItem.h"

@class Repo, Org, LocalProject;

@interface Project : MetadataItem

- (id)initWithLocalItem:(LocalProject *)lp owningRepo:(Repo *)repository;

- (id)initWithLocalItem:(LocalProject *)lp owningOrg:(Org *)organization;

@property (readonly) NSNumber *number;
@property (readonly) NSString *name;
@property (readonly) NSString *body;
@property (readonly) NSDate *updatedAt;
@property (readonly) NSDate *createdAt;

@property (weak, readonly) Repo *repository;
@property (weak, readonly) Org *organization;

@end

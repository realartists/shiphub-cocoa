//
//  Project.m
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Project.h"

#import "LocalProject.h"
#import "Repo.h"
#import "Org.h"

@implementation Project

- (id)initWithLocalItem:(LocalProject *)lp owningRepo:(Repo *)repository
{
    if (self = [super initWithLocalItem:lp]) {
        [self commonInitWithLocalProject:lp];
        _repository = repository;
    }
    return self;
}

- (id)initWithLocalItem:(LocalProject *)lp owningOrg:(Org *)organization
{
    if (self = [super initWithLocalItem:lp]) {
        [self commonInitWithLocalProject:lp];
        _organization = organization;
    }
    return self;
}

- (id)initWithLocalItem:(LocalProject *)lp {
    if (self = [super initWithLocalItem:lp]) {
        [self commonInitWithLocalProject:lp];
    }
    return self;
}

- (void)commonInitWithLocalProject:(LocalProject *)lp {
    _number = lp.number;
    _name = lp.name;
    _body = lp.body;
    _createdAt = lp.createdAt;
    _updatedAt = lp.updatedAt;
}

@end

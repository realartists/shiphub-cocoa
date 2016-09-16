//
//  Project.m
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Project.h"

#import "LocalProject.h"

@implementation Project

- (id)initWithLocalItem:(LocalProject *)lp {
    if (self = [super initWithLocalItem:lp]) {
        _number = lp.number;
        _name = lp.name;
        _body = lp.body;
        _createdAt = lp.createdAt;
        _updatedAt = lp.updatedAt;
    }
    return self;
}

@end

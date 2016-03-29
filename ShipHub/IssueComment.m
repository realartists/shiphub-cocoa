//
//  IssueComment.m
//  ShipHub
//
//  Created by James Howard on 3/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueComment.h"

#import "LocalComment.h"
#import "MetadataStoreInternal.h"

#import "LocalUser.h"
#import "User.h"

@implementation IssueComment

- (instancetype)initWithLocalComment:(LocalComment *)lc metadataStore:(MetadataStore *)ms
{
    if (self = [super init]) {
        _body = lc.body;
        _createdAt = lc.createdAt;
        _identifier = lc.identifier;
        _updatedAt = lc.updatedAt;
        _user = [ms userWithLocalUser:lc.user];
    }
    return self;
}

@end

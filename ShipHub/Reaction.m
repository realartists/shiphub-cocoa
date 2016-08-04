//
//  Reaction.m
//  ShipHub
//
//  Created by James Howard on 8/3/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Reaction.h"

#import "MetadataStore.h"
#import "User.h"

#import "LocalReaction.h"
#import "LocalUser.h"

@implementation Reaction

- (instancetype)initWithLocalReaction:(LocalReaction *)lr metadataStore:(MetadataStore *)ms
{
    if (self = [super init]) {
        _user = [ms userWithIdentifier:lr.user.identifier];
        _content = lr.content;
        _createdAt = lr.createdAt;
        _identifier = lr.identifier;
    }
    return self;
}

- (NSString *)description {
    return _content;
}

@end

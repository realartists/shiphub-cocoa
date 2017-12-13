//
//  Reaction.m
//  ShipHub
//
//  Created by James Howard on 8/3/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Reaction.h"

#import "Account.h"
#import "Extras.h"

#if TARGET_SHIP
#import "MetadataStore.h"
#import "LocalAccount.h"
#import "LocalReaction.h"
#endif

@implementation Reaction

#if TARGET_SHIP
- (instancetype)initWithLocalReaction:(LocalReaction *)lr metadataStore:(MetadataStore *)ms
{
    if (self = [super initWithLocalItem:lr]) {
        _user = [ms accountWithIdentifier:lr.user.identifier];
        _content = lr.content;
        _createdAt = lr.createdAt;
    }
    return self;
}
#endif

- (instancetype)initWithDictionary:(NSDictionary *)d {
    if (self = [super initWithDictionary:d]) {
        _user = [[Account alloc] initWithDictionary:d[@"user"]];
        _content = d[@"content"];
        _createdAt = [NSDate dateWithJSONString:d[@"created_at"]];
    }
    return self;
}

- (NSString *)description {
    return _content;
}

@end

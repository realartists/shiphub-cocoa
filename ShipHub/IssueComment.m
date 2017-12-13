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

#import "LocalAccount.h"
#import "Account.h"
#import "Reaction.h"
#import "Extras.h"

@implementation IssueComment

#if TARGET_SHIP
- (instancetype)initWithLocalComment:(LocalComment *)lc metadataStore:(MetadataStore *)ms
{
    if (self = [super init]) {
        _body = lc.body;
        _createdAt = lc.createdAt;
        _identifier = lc.identifier;
        _updatedAt = lc.updatedAt;
        _user = [ms accountWithLocalAccount:lc.user];
        _reactions = [[lc.reactions allObjects] arrayByMappingObjects:^id(id obj) {
            return [[Reaction alloc] initWithLocalReaction:obj metadataStore:ms];
        }];
    }
    return self;
}
#endif

- (NSString *)description {
    NSString *body = _body;
    if (body.length > 40) {
        body = [NSString stringWithFormat:@"\"%@ ...\"", [_body substringToIndex:40]];
    } else {
        body = [NSString stringWithFormat:@"\"%@\"", _body];
    }
    return [NSString stringWithFormat:@"<%@ %p> %@", NSStringFromClass([self class]), self, body];
}

@end

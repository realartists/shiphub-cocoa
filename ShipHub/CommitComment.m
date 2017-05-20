//
//  CommitComment.m
//  ShipHub
//
//  Created by James Howard on 5/19/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "CommitComment.h"

#import "LocalCommitComment.h"
#import "MetadataStoreInternal.h"

#import "LocalAccount.h"
#import "Account.h"
#import "Reaction.h"
#import "Extras.h"

@implementation CommitComment

- (instancetype)initWithLocalCommitComment:(LocalCommitComment *)lc metadataStore:(MetadataStore *)ms
{
    if (self = [super init]) {
        self.body = lc.body;
        self.commitId = lc.commitId;
        self.line = lc.line;
        self.position = lc.position;
        self.createdAt = lc.createdAt;
        self.identifier = lc.identifier;
        self.updatedAt = lc.updatedAt;
        self.user = [ms accountWithLocalAccount:lc.user];
        self.reactions = [[lc.reactions allObjects] arrayByMappingObjects:^id(id obj) {
            return [[Reaction alloc] initWithLocalReaction:obj metadataStore:ms];
        }];
    }
    return self;
}

@end

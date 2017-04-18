//
//  PRComment.m
//  ShipHub
//
//  Created by James Howard on 2/14/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRComment.h"

#import "Extras.h"
#import "MetadataStore.h"
#import "Account.h"
#import "Reaction.h"
#import "LocalPRComment.h"
#import "LocalPRReview.h"
#import "MetadataStoreInternal.h"

@implementation PRComment

static NSNumber *getNum(NSDictionary *d, NSString *field) {
    id v = d[field];
    if (![v isKindOfClass:[NSNumber class]]) {
        return nil;
    }
    return v;
}

- (id)initWithDictionary:(NSDictionary *)d metadataStore:(MetadataStore *)store {
    if (self = [super init]) {
        _pullRequestReviewId = d[@"pull_request_review_id"];
        _diffHunk = d[@"diff_hunk"];
        _path = d[@"path"];
        _position = getNum(d, @"position");
        _originalPosition = getNum(d, @"original_position");
        _commitId = d[@"commit_id"];
        _originalCommitId = d[@"original_commit_id"];
        _inReplyTo = d[@"in_reply_to"];
        
        self.body = d[@"body"];
        self.createdAt = [NSDate dateWithJSONString:d[@"created_at"]];
        self.updatedAt = [NSDate dateWithJSONString:d[@"updated_at"]];
        self.identifier = d[@"id"];
        
        self.user = [store accountWithIdentifier:d[@"user"][@"id"]];
        
        // TODO: Reactions
    }
    return self;
}

- (id)initWithLocalPRComment:(LocalPRComment *)lc metadataStore:(MetadataStore *)ms
{
    if (self = [super init]) {
        self.body = lc.body;
        self.createdAt = lc.createdAt;
        self.identifier = lc.identifier;
        self.updatedAt = lc.updatedAt;
        self.user = [ms accountWithLocalAccount:lc.user];
        self.reactions = [[lc.reactions allObjects] arrayByMappingObjects:^id(id obj) {
            return [[Reaction alloc] initWithLocalReaction:obj metadataStore:ms];
        }];
        
        _pullRequestReviewId = lc.review.identifier;
        _diffHunk = lc.diffHunk;
        _path = lc.path;
        _position = lc.position;
        _originalPosition = lc.originalPosition;
        _commitId = lc.commitId;
        _originalCommitId = lc.originalCommitId;
        _inReplyTo = lc.inReplyTo;
        
        // re-fault the comment to avoid retain cycle with the review
        [[lc managedObjectContext] refreshObject:lc mergeChanges:NO];
    }
    return self;
}

@end

@implementation PendingPRComment

- (id)initWithDictionary:(NSDictionary *)d metadataStore:(MetadataStore *)store {
    
    if (self = [super initWithDictionary:d metadataStore:store]) {
        _pendingId = d[@"pending_id"] ?: [d[@"id"] description];
        self.identifier = nil;
    }
    return self;
}

@end

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

@implementation PRComment

- (id)initWithDictionary:(NSDictionary *)d metadataStore:(MetadataStore *)store {
    if (self = [super init]) {
        _pullRequestReviewId = d[@"pull_request_review_id"];
        _diffHunk = d[@"diff_hunk"];
        _path = d[@"path"];
        _position = d[@"position"];
        _originalPosition = d[@"original_position"];
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

@end

@implementation PendingPRComment

- (id)initWithDictionary:(NSDictionary *)d metadataStore:(MetadataStore *)store {
    
    if (self = [super initWithDictionary:d metadataStore:store]) {
        _pendingId = d[@"pending_id"];
    }
    return self;
}

@end

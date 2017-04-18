//
//  PRComment.h
//  ShipHub
//
//  Created by James Howard on 2/14/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IssueComment.h"

@class LocalPRComment;

@interface PRComment : IssueComment

@property NSNumber *pullRequestReviewId;
@property NSString *diffHunk;
@property NSString *path;
@property NSNumber *position;
@property NSNumber *originalPosition;
@property NSString *commitId;
@property NSString *originalCommitId;
@property NSNumber *inReplyTo;

- (id)initWithDictionary:(NSDictionary *)d metadataStore:(MetadataStore *)store;
- (id)initWithLocalPRComment:(LocalPRComment *)lc metadataStore:(MetadataStore *)store;

@end

@interface PendingPRComment : PRComment

@property NSString *pendingId;

@end

//
//  CommitComment.h
//  ShipHub
//
//  Created by James Howard on 5/19/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "IssueComment.h"

@class Account;

#if TARGET_SHIP
@class LocalCommitComment;
@class MetadataStore;
#endif

@interface CommitComment : IssueComment

@property NSString *commitId;
@property NSNumber *line;
@property NSNumber *path;
@property NSNumber *position;

#if TARGET_SHIP
- (instancetype)initWithLocalCommitComment:(LocalCommitComment *)lc metadataStore:(MetadataStore *)ms;
#endif

@end

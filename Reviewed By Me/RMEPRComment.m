//
//  RMEPRComment.m
//  Reviewed By Me
//
//  Created by James Howard on 12/6/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEPRComment.h"

#import "Extras.h"
#import "RMEAccount.h"

@implementation RMEPRComment

- (id)initWithGraphQL:(NSDictionary *)gql {
    if (self = [super init]) {
        self.identifier = gql[@"databaseId"];
        self.user = [[RMEAccount alloc] initWithGraphQL:gql[@"author"]];
        self.body = gql[@"body"];
        self.createdAt = [NSDate dateWithJSONString:gql[@"createdAt"]];
        self.updatedAt = [NSDate dateWithJSONString:gql[@"lastEditedAt"]];
        self.pullRequestReviewId = gql[@"pullRequestReview"][@"databaseId"];
        
        self.diffHunk = gql[@"diffHunk"];
        self.path = gql[@"path"];
        self.position = gql[@"position"];
        self.originalPosition = gql[@"originalPoosition"];
        self.commitId = gql[@"commit"][@"oid"];
        self.originalCommitId = gql[@"originalCommit"][@"oid"];
        self.inReplyTo = gql[@"replyTo"][@"databaseId"];
        
        // FIXME: Reactions
    }
    return self;
}

@end

//
//  RMEPRReview.m
//  Reviewed By Me
//
//  Created by James Howard on 12/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEPRReview.h"

#import "Extras.h"
#import "RMEAccount.h"
#import "RMEPRComment.h"

@implementation RMEPRReview

- (id)initWithGraphQL:(NSDictionary *)gql {
    if (self = [super init]) {
        self.identifier = gql[@"databaseId"];
        self.user = [[RMEAccount alloc] initWithGraphQL:gql[@"author"]];
        self.state = PRReviewStateFromString(gql[@"state"]);
        self.createdAt = [NSDate dateWithJSONString:gql[@"createdAt"]];
        self.submittedAt = [NSDate dateWithJSONString:gql[@"submittedAt"]];
        self.body = gql[@"body"];
        self.commitId = gql[@"commit"][@"oid"];
        NSArray *comments = [gql valueForKeyPath:@"comments.edges.node"];
        comments = [comments arrayByMappingObjects:^id(id obj) {
            return [[RMEPRComment alloc] initWithGraphQL:obj];
        }];
        self.comments = comments;
    }
    return self;
}

@end

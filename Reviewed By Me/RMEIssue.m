//
//  RMEIssue.m
//  Reviewed By Me
//
//  Created by James Howard on 12/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEIssue.h"

#import "Extras.h"
#import "IssueInternal.h"
#import "IssueIdentifier.h"
#import "Repo.h"
#import "RMEAccount.h"
#import "RMEPRReview.h"

@implementation RMEIssue

static NSDictionary *V3RefFromV4(NSDictionary *v4);

- (id)initWithGraphQL:(NSDictionary *)gql repository:(Repo *)repo {
    if (self = [super init]) {
        self.repository = repo;
        self.number = gql[@"number"];
        self.identifier = gql[@"databaseId"];
        self.title = gql[@"title"];
        self.closed = [gql[@"closed"] boolValue];
        self.createdAt = [NSDate dateWithJSONString:gql[@"createdAt"]];
        self.updatedAt = [NSDate dateWithJSONString:gql[@"updatedAt"]];
        self.closedAt = [NSDate dateWithJSONString:gql[@"closedAt"]];
        self.locked = [gql[@"locked"] boolValue];
        
        static NSArray *assigneesSort = nil;
        static NSArray *labelsSort = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            assigneesSort = @[[NSSortDescriptor sortDescriptorWithKey:@"login" ascending:YES selector:@selector(localizedStandardCompare:)]];
            labelsSort = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)]];
        });
        
        NSArray *assignees = [[gql valueForKeyPath:@"assignees.edges.node"] arrayByMappingObjects:^id(id obj) {
            return [[RMEAccount alloc] initWithGraphQL:obj];
        }];
        
        self.assignees = [assignees sortedArrayUsingDescriptors:assigneesSort];
        
        self.originator = [[RMEAccount alloc] initWithGraphQL:gql[@"author"]];
        
        self.closedBy = [[RMEAccount alloc] initWithGraphQL:gql[@"closedBy"]];

        // TODO: Labels
        
        self.fullIdentifier = [NSString issueIdentifierWithOwner:repo.owner.login repo:repo.name number:self.number];
        
        self.pullRequest = YES;
        
        self.pullRequestIdentifier = gql[@"databaseId"]; // FIXME: Inaccurate
        
        NSString *mergeableState = nil;
        NSString *gqlMergeable = gql[@"mergeable"] ?: @"UNKNOWN";
        if ([gqlMergeable caseInsensitiveCompare:@"CONFLICTING"] == NSOrderedSame) {
            self.mergeable = @NO;
            mergeableState = @"blocked";
        } else if ([gqlMergeable caseInsensitiveCompare:@"MERGEABLE"] == NSOrderedSame) {
            self.mergeable = @YES;
            mergeableState = @"clean";
        } else {
            self.mergeable = @NO;
            mergeableState = @"unknown";
        }
        
        self.mergeableState = mergeableState;
        
        self.mergeCommitSha = gql[@"mergeCommit"][@"oid"];
        
        self.mergedAt = [NSDate dateWithJSONString:gql[@"mergedAt"]];
        
        self.additions = gql[@"additions"];
        self.deletions = gql[@"deletions"];
        self.changedFiles = gql[@"changedFiles"];
        
        self.base = V3RefFromV4(gql[@"baseRef"]);
        self.head = V3RefFromV4(gql[@"headRef"]);
        
        // TODO: Requested Reviewers
        
        NSArray *reviews = [[gql valueForKeyPath:@"reviews.edges.node"] arrayByMappingObjects:^id(id obj) {
            return [[RMEPRReview alloc] initWithGraphQL:obj];
        }];
        
        self.reviews = [reviews sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"submittedAt" ascending:YES]]];
        
    }
    return self;
}

static NSDictionary *V3RefFromV4(NSDictionary *v4) {
    
    NSDictionary *repo = @{ @"id" : v4[@"repository"][@"databaseId"],
                            @"name" : v4[@"repository"][@"name"],
                            @"fullName" : v4[@"repository"][@"nameWithOwner"],
                            @"defaultBranch" : v4[@"repository"][@"defaultBranchRef"][@"name"]
                            };
    
    return @{ @"ref" : v4[@"name"],
              @"label" : v4[@"name"],
              @"sha" : v4[@"target"][@"oid"],
              @"repo" : repo };
}

@end


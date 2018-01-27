//
//  LocalPullRequest.m
//  ShipHub
//
//  Created by James Howard on 5/3/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "LocalPullRequest.h"

@implementation LocalPullRequest

@dynamic identifier;
@dynamic maintainerCanModify;
@dynamic mergeable;
@dynamic mergeableState;
@dynamic mergeCommitSha;
@dynamic merged;
@dynamic mergedAt;
@dynamic mergedBy;
@dynamic requestedReviewers;
@dynamic baseBranch;
@dynamic base;
@dynamic head;
@dynamic createdAt;
@dynamic updatedAt;
@dynamic issue;
@dynamic additions;
@dynamic deletions;
@dynamic commits;
@dynamic rebaseable;
@dynamic changedFiles;
@dynamic shipHeadBranch;
@dynamic shipHeadRepoFullName;

- (nullable id)computeBaseBranchForProperty:(nullable NSString *)propertyKey inDictionary:(nullable NSDictionary *)d
{
    NSString *baseBranch = d[@"base"][@"ref"];
    return baseBranch;
}

- (nullable id)computeHeadBranchForProperty:(nullable NSString *)propertyKey inDictionary:(nullable NSDictionary *)d
{
    NSString *headBranch = d[@"head"][@"ref"];
    return headBranch;
}

- (nullable id)computeHeadRepoFullNameForProperty:(nullable NSString *)propertyKey inDictionary:(nullable NSDictionary *)d
{
    @try {
        return [d valueForKeyPath:@"head.repo.fullName"];
    } @catch (id exc) {
        return nil;
    }
}

@end

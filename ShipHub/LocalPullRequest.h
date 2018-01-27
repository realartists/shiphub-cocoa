//
//  LocalPullRequest.h
//  ShipHub
//
//  Created by James Howard on 5/3/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@class LocalAccount;
@class LocalIssue;

@interface LocalPullRequest : NSManagedObject

@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSNumber *maintainerCanModify;
@property (nullable, nonatomic, retain) NSNumber *mergeable;
@property (nullable, nonatomic, retain) NSString *mergeableState;
@property (nullable, nonatomic, retain) NSNumber *rebaseable;
@property (nullable, nonatomic, retain) NSString *mergeCommitSha;
@property (nullable, nonatomic, retain) NSNumber *merged;
@property (nullable, nonatomic, retain) NSDate *mergedAt;
@property (nullable, nonatomic, retain) LocalAccount *mergedBy;
@property (nullable, nonatomic, retain) NSNumber *additions;
@property (nullable, nonatomic, retain) NSNumber *changedFiles;
@property (nullable, nonatomic, retain) NSNumber *deletions;
@property (nullable, nonatomic, retain) NSNumber *commits;

@property (nullable, nonatomic, retain) NSSet<LocalAccount *> *requestedReviewers;

@property (nullable, nonatomic, retain) id<NSCoding> base;
@property (nullable, nonatomic, retain) id<NSCoding> head;

@property (nullable, nonatomic, retain) NSString *baseBranch;
@property (nullable, nonatomic, retain) NSString *shipHeadBranch;
@property (nullable, nonatomic, retain) NSString *shipHeadRepoFullName;

@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) NSDate *updatedAt;

@property (nullable, nonatomic, retain) LocalIssue *issue;

- (nullable id)computeBaseBranchForProperty:(nullable NSString *)propertyKey inDictionary:(nullable NSDictionary *)d;

- (nullable id)computeHeadBranchForProperty:(nullable NSString *)propertyKey inDictionary:(nullable NSDictionary *)d;

- (nullable id)computeHeadRepoFullNameForProperty:(nullable NSString *)propertyKey inDictionary:(nullable NSDictionary *)d;

@end

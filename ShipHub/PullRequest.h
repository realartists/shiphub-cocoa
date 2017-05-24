//
//  PullRequest.h
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PRMergeStrategy.h"

@class Issue;
@class GitDiff;
@class GitCommit;
@class PRComment;
@class PRReview;

@interface PullRequest : NSObject

- (instancetype)initWithIssue:(Issue *)issue;

@property (readonly) Issue *issue;

+ (BOOL)isGitHubFilesURL:(NSURL *)URL;
+ (id)issueIdentifierForGitHubFilesURL:(NSURL *)URL commentIdentifier:(NSNumber *__autoreleasing *)outCommentIdentifier;
+ (NSURL *)gitHubFilesURLForIssueIdentifier:(id)issueIdentifier;
- (NSURL *)gitHubFilesURL;

- (NSProgress *)checkout:(void (^)(NSError *error))completion;

// All of the following properties and methods are available only after checkout has completed.
@property (readonly) NSArray<PRComment *> *prComments;
@property (readonly) GitDiff *spanDiff;
@property (readonly) GitDiff *spanDiffSinceMyLastReview;
@property (readonly) GitDiff *spanDiffSinceMyLastView;
@property (readonly) NSArray<GitCommit *> *commits;
@property (readonly) PRReview *myLastSubmittedReview;
@property (readonly) PRReview *myLastPendingReview;
@property (readonly) NSString *bareRepoPath;
@property (readonly) NSURL *githubRemoteURL;
@property (readonly) NSString *headRefSpec;
@property (readonly) NSString *headSha;
@property (readonly) NSString *baseSha;
@property (readonly) BOOL canMerge;
@property (readonly, getter=isMerged) BOOL merged;

@property (readonly) NSString *mergeTitle; // default title on merge
@property (readonly) NSString *mergeMessage;  // default message on merge

@property (readonly) NSString *headDescription; // e.g. james/1234 or realartists/test:james/1234
@property (readonly) NSString *baseDescription; // e.g. realartists/test:master

// returns YES if lightweight update was possible, no if a new PullRequest object and checkout needs to happen.
- (BOOL)lightweightMergeUpdatedIssue:(Issue *)issue;

- (void)mergeComments:(NSArray<PRComment *> *)comments;
- (void)deleteComments:(NSArray<PRComment *> *)comments;

- (void)performMergeWithMethod:(PRMergeStrategy)strat
                         title:(NSString *)title
                       message:(NSString *)message
                    completion:(void (^)(NSError *))completion;

- (NSProgress *)revertMerge:(NSString *)mergeCommit withCompletion:(void (^)(Issue *prTemplate, NSError *error))completion;

@end

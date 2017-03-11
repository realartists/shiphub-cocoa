//
//  PullRequest.h
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Issue;
@class GitDiff;
@class PRComment;
@class PRReview;

typedef NS_ENUM(NSInteger, PRMergeStrategy) {
    PRMergeStrategyMerge = 0,
    PRMergeStrategySquash,
    PRMergeStrategyRebase
};

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
@property (readonly) PRReview *myLastPendingReview;
@property (readonly) NSString *bareRepoPath;
@property (readonly) NSURL *githubRemoteURL;
@property (readonly) NSString *headRefSpec;
@property (readonly) BOOL canMerge;

@property (readonly) NSString *mergeTitle; // default title on merge
@property (readonly) NSString *mergeMessage;  // default message on merge

- (void)mergeComments:(NSArray<PRComment *> *)comments;
- (void)deleteComments:(NSArray<PRComment *> *)comments;

- (void)performMergeWithMethod:(PRMergeStrategy)strat
                         title:(NSString *)title
                       message:(NSString *)message
                    completion:(void (^)(NSError *))completion;

@end

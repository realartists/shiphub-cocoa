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

@interface PullRequest : NSObject

- (instancetype)initWithIssue:(Issue *)issue;

@property (readonly) Issue *issue;

- (NSProgress *)checkout:(void (^)(NSError *error))completion;

@property (readonly) NSArray<PRComment *> *prComments; // available after checkout is completed
@property (readonly) GitDiff *spanDiff; // available after checkout is completed
@property (readonly) PRReview *myLastPendingReview; // available after checkout is completed
@property (readonly) NSString *bareRepoPath; // available after checkout
@property (readonly) NSURL *githubRemoteURL;
@property (readonly) NSString *headRefSpec;

+ (BOOL)isGitHubFilesURL:(NSURL *)URL;
+ (id)issueIdentifierForGitHubFilesURL:(NSURL *)URL commentIdentifier:(NSNumber *__autoreleasing *)outCommentIdentifier;
+ (NSURL *)gitHubFilesURLForIssueIdentifier:(id)issueIdentifier;
- (NSURL *)gitHubFilesURL;

- (void)mergeComments:(NSArray<PRComment *> *)comments;
- (void)deleteComments:(NSArray<PRComment *> *)comments;

@end

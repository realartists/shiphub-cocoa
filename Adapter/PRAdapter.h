//
//  PRAdapter.h
//  ShipHub
//
//  Created by James Howard on 11/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Account;
@class Auth;
@class Reaction;
@class Issue;
@class Repo;
@class PRComment;
@class PRReview;

#import "PRMergeStrategy.h"

@protocol PRAdapter <NSObject>

- (Auth *)auth;

- (void)checkForIssueUpdates;

- (Reaction *)createReactionWithTemporaryId:(NSNumber *)temporaryId content:(NSString *)reactionContent createdAt:(NSDate *)date user:(Account *)user;

- (Issue *)createPRRevertIssueWithTitle:(NSString *)title repo:(Repo *)repo body:(NSString *)body baseInfo:(NSDictionary *)base headInfo:(NSDictionary *)head;

- (__kindof PRComment *)createPRCommentWithClass:(Class)commentClass dictionary:(NSDictionary *)commentDict;

- (void)reloadFullIssueWithCompletion:(void (^)(Issue * issue, NSError *error))completion;

- (NSArray<Account *> *)assigneesForRepo;

- (void)postPRCommentReaction:(Reaction *)reaction inPRComment:(NSNumber *)commentIdentifier completion:(void (^)(Reaction *roundtrip, NSError *error))completion;

- (void)deleteReaction:(NSNumber *)reactionIdentifier completion:(void (^)(NSError *error))completion;

- (void)addReview:(PRReview *)review completion:(void (^)(PRReview *roundtrip, NSError *error))completion;

- (void)addSingleReviewComment:(PRComment *)comment completion:(void (^)(PRComment *roundtrip, NSError *error))completion;

- (void)editReviewComment:(PRComment *)comment completion:(void (^)(PRComment *roundtrip, NSError *error))completion;

- (void)deleteReviewComment:(PRComment *)comment completion:(void (^)(NSError *error))completion;

- (void)storeLastViewedHeadSha:(NSString *)headSha completion:(void (^)(NSString *lastSha, NSError *error))completion;

- (void)mergePullRequestWithStrategy:(PRMergeStrategy)strat title:(NSString *)title message:(NSString *)message completion:(void (^)(Issue *issue, NSError *error))completion;

- (void)deletePullRequestBranchWithCompletion:(void (^)(NSError *error))completion;

- (void)openConversationView;

@end

extern id<PRAdapter> CreatePRAdapter(Issue * issue);

// Notifications, all posted by PRAdapter object
#define PRAdapterDidUpdateIssueNotification @"PRAdapterDidUpdateIssueNotification"



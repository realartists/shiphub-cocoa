//
//  RMEPRAdapter.m
//  Reviewed By Me
//
//  Created by James Howard on 11/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEPRAdapter.h"

#import "RMEDataStore.h"

#import "Account.h"
#import "Auth.h"
#import "Issue.h"
#import "IssueIdentifier.h"
#import "Reaction.h"
#import "Repo.h"

#import "RMEIssue.h"
#import "RMERepo.h"
#import "RMEPRLoader.h"

@interface RMEPRAdapter ()

- (id)initWithIssue:(Issue *)issue;

@property (readonly) Issue *issue;

@end

@implementation RMEPRAdapter

- (id)initWithIssue:(Issue *)issue {
    if (self = [super init]) {
        _issue = issue;
    }
    return self;
}

- (Auth *)auth {
    return [[RMEDataStore activeStore] auth];
}

- (Reaction *)createReactionWithTemporaryId:(NSNumber *)temporaryId content:(NSString *)reactionContent createdAt:(NSDate *)date user:(Account *)user
{
    Reaction *r = [Reaction new];
    r.identifier = temporaryId;
    r.content = reactionContent;
    r.createdAt = date;
    r.user = user;
    return r;
}

- (Issue *)createPRRevertIssueWithTitle:(NSString *)title repo:(Repo *)repo body:(NSString *)body baseInfo:(NSDictionary *)baseInfo headInfo:(NSDictionary *)headInfo
{
    return [[Issue alloc] initPRWithTitle:[NSString stringWithFormat:@"Revert %@", title] repo:(Repo *)repo body:@"" baseInfo:baseInfo headInfo:headInfo];
}

- (PRComment *)createPRCommentWithClass:(Class)commentClass dictionary:(NSDictionary *)commentDict
{
    return [[commentClass alloc] initWithDictionary:commentDict];
}

- (void)reloadFullIssueWithCompletion:(void (^)(Issue *, NSError *))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (NSArray<Account *> *)assigneesForRepo {
    return [(RMERepo *)self.issue.repository assignable];
}

- (void)postPRCommentReaction:(Reaction *)reaction inPRComment:(NSNumber *)commentIdentifier completion:(void (^)(Reaction * roundtrip, NSError *error))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (void)deleteReaction:(NSNumber *)reactionIdentifier completion:(void (^)(NSError *error))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (void)addReview:(PRReview *)review completion:(void (^)(PRReview *roundtrip, NSError *error))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (void)addSingleReviewComment:(PRComment *)comment completion:(void (^)(PRComment *roundtrip, NSError *error))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (void)editReviewComment:(PRComment *)comment completion:(void (^)(PRComment *roundtrip, NSError *error))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (void)deleteReviewComment:(PRComment *)comment completion:(void (^)(NSError *error))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (void)storeLastViewedHeadSha:(NSString *)headSha completion:(void (^)(NSString *lastSha, NSError *error))completion
{
    [[RMEDataStore activeStore] storeLastViewedHeadSha:headSha forPullRequestIdentifier:self.issue.fullIdentifier pullRequestTitle:self.issue.title completion:completion];
}

- (void)checkForIssueUpdates {
    // nop
}

- (void)mergePullRequestWithStrategy:(PRMergeStrategy)strat title:(NSString *)title message:(NSString *)message completion:(void (^)(Issue *issue, NSError *error))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (void)deletePullRequestBranchWithCompletion:(void (^)(NSError *error))completion
{
    // TODO
    [self doesNotRecognizeSelector:_cmd];
}

- (void)openConversationView {
    NSURL *URL = [_issue.fullIdentifier pullRequestGitHubURL];
    [[NSWorkspace sharedWorkspace] openURL:URL];
}

@end


id<PRAdapter> CreatePRAdapter(Issue * issue) {
    return [[RMEPRAdapter alloc] initWithIssue:(Issue *)issue];
}

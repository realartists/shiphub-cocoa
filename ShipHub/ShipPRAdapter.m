//
//  ShipPRAdapter.m
//  Ship
//
//  Created by James Howard on 11/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "ShipPRAdapter.h"

#import "DataStore.h"
#import "MetadataStore.h"
#import "Account.h"
#import "Issue.h"
#import "IssueDocumentController.h"
#import "Repo.h"
#import "Reaction.h"

@interface ShipPRAdapter ()

- (id)initWithIssue:(Issue *)issue;

@property (readonly) Issue *issue;

@end

@implementation ShipPRAdapter

- (id)initWithIssue:(Issue *)issue {
    if (self = [super init]) {
        _issue = issue;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(issueDidUpdate:) name:DataStoreDidUpdateProblemsNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (Auth *)auth {
    return [[DataStore activeStore] auth];
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
    return [[commentClass alloc] initWithDictionary:commentDict metadataStore:[[DataStore activeStore] metadataStore]];
}

- (void)reloadFullIssueWithCompletion:(void (^)(Issue *, NSError *))completion {
    [[DataStore activeStore] loadFullIssue:_issue.fullIdentifier completion:^(Issue *issue, NSError *error) {
        completion(issue, error);
    }];
}

- (void)issueDidUpdate:(NSNotification *)note {
    if ([note object] == [DataStore activeStore]) {
        NSArray *updated = note.userInfo[DataStoreUpdatedProblemsKey];
        if ([updated containsObject:_issue.fullIdentifier]) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PRAdapterDidUpdateIssueNotification object:self userInfo:note.userInfo];
        }
    }
}

- (NSArray<Account *> *)assigneesForRepo {
    DataStore *ds = [DataStore activeStore];
    MetadataStore *ms = [ds metadataStore];
    NSArray *accounts = [ms assigneesForRepo:_issue.repository];
    return accounts;
}

- (void)postPRCommentReaction:(Reaction *)reaction inPRComment:(NSNumber *)commentIdentifier completion:(void (^)(Reaction * roundtrip, NSError *error))completion
{
    [[DataStore activeStore] postPRCommentReaction:reaction.content inRepoFullName:_issue.repository.fullName inPRComment:commentIdentifier completion:^(Reaction *roundtrip, NSError *error) {
        completion(roundtrip, error);
    }];
}

- (void)deleteReaction:(NSNumber *)reactionIdentifier completion:(void (^)(NSError *error))completion
{
    [[DataStore activeStore] deleteReaction:reactionIdentifier completion:completion];
}

- (void)addReview:(PRReview *)review completion:(void (^)(PRReview *roundtrip, NSError *error))completion
{
    [[DataStore activeStore] addReview:review inIssue:_issue.fullIdentifier completion:completion];
}

- (void)addSingleReviewComment:(PRComment *)comment completion:(void (^)(PRComment *roundtrip, NSError *error))completion
{
    [[DataStore activeStore] addSingleReviewComment:comment inIssue:_issue.fullIdentifier completion:completion];
}

- (void)editReviewComment:(PRComment *)comment completion:(void (^)(PRComment *roundtrip, NSError *error))completion
{
    [[DataStore activeStore] editReviewComment:comment inIssue:_issue.fullIdentifier completion:completion];
}

- (void)deleteReviewComment:(PRComment *)comment completion:(void (^)(NSError *error))completion
{
    [[DataStore activeStore] deleteReviewComment:comment inIssue:_issue.fullIdentifier completion:completion];
}

- (void)storeLastViewedHeadSha:(NSString *)headSha completion:(void (^)(NSString *lastSha, NSError *error))completion {
    [[DataStore activeStore] storeLastViewedHeadSha:[self _headRev] forPullRequestIdentifier:[_issue fullIdentifier] completion:completion];
}

- (void)checkForIssueUpdates {
    [[DataStore activeStore] checkForIssueUpdates:_issue.fullIdentifier];
}

- (void)mergePullRequestWithStrategy:(PRMergeStrategy)strat title:(NSString *)title message:(NSString *)message completion:(void (^)(Issue *issue, NSError *error))completion
{
    [[DataStore activeStore] mergePullRequest:_issue.fullIdentifier strategy:strat title:title message:message completion:completion];
}

- (void)deletePullRequestBranchWithCompletion:(void (^)(NSError *error))completion {
    [[DataStore activeStore] deletePullRequestBranch:_issue completion:completion];
}

- (void)openConversationView {
    IssueDocumentController *idc = [IssueDocumentController sharedDocumentController];
    [idc openIssueWithIdentifier:_pr.issue.fullIdentifier];
}

@end

id<PRAdapter> CreatePRAdapter(Issue * issue) {
    return [[ShipPRAdapter alloc] initWithIssue:(Issue *)issue];
}

//
//  PullRequest.m
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PullRequest.h"

#import "Account.h"
#import "Auth.h"
#import "DataStore.h"
#import "Error.h"
#import "Extras.h"
#import "Issue.h"
#import "Repo.h"
#import "IssueIdentifier.h"
#import "RequestPager.h"
#import "ServerConnection.h"
#import "PRComment.h"
#import "PRReview.h"

#import "GitDiff.h"
#import "GitCommit.h"
#import "GitRepo.h"

@interface PullRequest ()

@property NSDictionary *info;
@property NSString *dir;
@property GitRepo *repo;
@property GitDiff *spanDiff;

@end

@implementation PullRequest

- (instancetype)initWithIssue:(Issue *)issue {
    if (self = [super init]) {
        _issue = issue;
    }
    return self;
}

- (NSString *)_baseRev {
    return _info[@"base"][@"sha"];
}

- (NSString *)_headRev {
    return _info[@"head"][@"sha"];
}

- (NSString *)headSha {
    return [self _headRev];
}

- (NSString *)baseSha {
    return [self _baseRev];
}

// runs on a background queue
- (NSError *)loadSpanDiff {
    NSError *err = nil;
    _spanDiff = [GitDiff diffWithRepo:_repo from:[self _baseRev] to:[self _headRev] error:&err];
    if (err) return err;
    
    return nil;
}

- (NSError *)loadCommits {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    NSError *err = nil;
    _commits = [GitCommit commitLogFrom:[self _baseRev] to:[self _headRev] inRepo:_repo error:&err];
    
    if (!err) {
        _spanDiff = [GitDiff diffWithRepo:_repo fromMergeBaseOfStart:[self _baseRev] to:[self _headRev] error:&err];
    }
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    
#if DEBUG
    DebugLog(@"Loaded %td commits and span diff in %.3fs", _commits.count, (end-start));
#else
    (void)start;
    (void)end;
#endif
    return err;
}

- (NSError *)loadSpanDiffSinceLastSubmittedReview {
    GitDiff *span = nil;
    if (_myLastSubmittedReview.commitId) {
        NSString *rev = _myLastSubmittedReview.commitId;
        if ([[self _headRev] isEqualToString:rev]) {
            span = [GitDiff emptyDiffAtRev:rev];
        } else {
            NSError *error = nil;
            span = [GitDiff diffWithRepo:_repo from:rev to:[self _headRev] error:&error];
            if (error) {
                // this is most likely due to a force push. the head rev of _myLastSubmittedReview no longer exists.
                // so just use the full span
                span = _spanDiff;
            }
        }
    }
    _spanDiffSinceMyLastReview = span;
    return nil;
}

+ (GitRepo *)repoAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    // TODO: Garbage collect old repos
    
    static dispatch_queue_t q;
    static dispatch_once_t onceToken;
    static NSMutableDictionary *directory;
    dispatch_once(&onceToken, ^{
        q = dispatch_queue_create(NULL, NULL);
        directory = [NSMutableDictionary new];
    });
    
    __block GitRepo *repo = nil;
    __block NSError *err = nil;
    dispatch_sync(q, ^{
        repo = directory[path];
        if (!repo) {
            NSError *outErr = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:NULL error:&outErr];
            if (!outErr) {
                repo = [GitRepo repoAtPath:path error:&outErr];
                err = outErr;
                if (repo) directory[path] = repo;
            }
        }
    });
    
    if (error) *error = err;
    return repo;
}

// runs on a background queue
- (NSError *)cloneWithProgress:(NSProgress *)progress {
    NSString *reposDir = [@"~/Library/RealArtists/Ship2/git" stringByExpandingTildeInPath];
    _dir = [NSString stringWithFormat:@"%@/%@", reposDir, _issue.repository.fullName];
    
    NSError *error = nil;
    _repo = [[self class] repoAtPath:_dir error:&error];
    if (error) {
        return error;
    }
    
    NSString *remoteURLStr = _info[@"base"][@"repo"][@"clone_url"]; // want to use the base, as this is "origin"
    
    if (remoteURLStr) {
        _githubRemoteURL = [NSURL URLWithString:remoteURLStr];
    }
    
    // See https://help.github.com/articles/checking-out-pull-requests-locally/
    NSString *refSpec = [NSString stringWithFormat:@"pull/%@/head", _issue.number];
    NSString *baseRefSpec = _info[@"base"][@"ref"];
    _headRefSpec = refSpec;
    
    // optimistically, see if we can find the PR without doing any network operations
    NSError *optimisticErr = [self loadCommits];
    if (optimisticErr) {
        progress.localizedDescription = NSLocalizedString(@"Fetching git objects", nil);
        progress.completedUnitCount = 0;
        progress.totalUnitCount = -1;
        
        DebugLog(@"Have to fetch refSpec %@ from %@", refSpec, remoteURLStr);
        
        // See https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth
        error = [_repo fetchRemote:_githubRemoteURL username:[[[DataStore activeStore] auth] ghToken] password:@"x-oauth-basic" refs:@[refSpec, baseRefSpec] progress:progress];
        if (error) return error;
        
        error = [self loadCommits];
        
        if (error) return error;
    } else {
        DebugLog(@"Loaded commits without network op");
    }
    
    if (progress.cancelled) return [NSError cancelError];
    
    progress.localizedDescription = NSLocalizedString(@"Preparing diffs", nil);
    progress.totalUnitCount = 2;
    progress.completedUnitCount = 1;
    
    error = [self loadSpanDiffSinceLastSubmittedReview];
    if (error) {
        ErrLog(@"Error loading span diff since last submitted review: %@", error);
        return error;
    }
    progress.completedUnitCount += 1;
    
    return error;
}

// runs on a background queue
- (NSError *)checkoutWithProgress:(NSProgress *)progress {
    Auth *auth = [[DataStore activeStore] auth];
    RequestPager *pager = [[RequestPager alloc] initWithAuth:auth];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    __block NSDictionary *prInfo = nil;
    __block NSError *prError = nil;
    
    NSInteger operations = 0;
    
    NSString *pullEndpoint = [NSString stringWithFormat:@"/repos/%@/pulls/%@", _issue.repository.fullName, _issue.number];
    [pager fetchSingleObject:[pager get:pullEndpoint] completion:^(NSDictionary *obj, NSError *err) {
        prError = err;
        prInfo = obj;
        dispatch_semaphore_signal(sema);
    }];
    operations++;
    
    progress.totalUnitCount = operations;
    progress.completedUnitCount = 0;
    progress.localizedDescription = NSLocalizedString(@"Loading pull request metadata", nil);
    
    // wait for responses
    while (operations != 0 && !progress.cancelled) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        operations--;
        progress.completedUnitCount += 1;
    }
    
    if (progress.cancelled) return [NSError cancelError];
    
    if (prError) return prError;
    
    _info = prInfo;
    [self lightweightMergeUpdatedIssue:_issue];
    
    return [self cloneWithProgress:progress];
}

- (NSProgress *)checkout:(void (^)(NSError *error))completion {
    NSParameterAssert(completion);
    
    NSProgress *progress = [NSProgress indeterminateProgress];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *err = [self checkoutWithProgress:progress];
        RunOnMain(^{
            completion(err);
        });
    });
    return progress;
}

+ (BOOL)isGitHubFilesURL:(NSURL *)URL {
    return [self issueIdentifierForGitHubFilesURL:URL commentIdentifier:NULL] != nil;
}

+ (id)issueIdentifierForGitHubFilesURL:(NSURL *)URL commentIdentifier:(NSNumber *__autoreleasing *)outCommentIdentifier
{
    // https://github.com/realartists/shiphub-server/pull/166/files
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSString *path = [components path];
    NSArray *pathParts = [path componentsSeparatedByString:@"/"];
    if (pathParts.count != 6 || ![pathParts[3] isEqualToString:@"pull"] || ![pathParts[5] isEqualToString:@"files"]) {
        return nil;
    }
    
    NSString *owner = pathParts[1];
    NSString *repo = pathParts[2];
    NSString *numberStr = pathParts[4];
    NSNumber *number = @([numberStr longLongValue]);
    NSString *fragment = [components fragment];
    
    NSNumber *num = nil;
    if (outCommentIdentifier && [fragment hasPrefix:@"r"]) {
        NSString *suffix = [fragment substringFromIndex:1];
        NSScanner *scanner = [NSScanner scannerWithString:suffix];
        uint64_t v = 0;
        if ([scanner scanUnsignedLongLong:&v]) {
            num = @(v);
        }
    }
    
    if (outCommentIdentifier) {
        *outCommentIdentifier = num;
    }
    
    return [NSString issueIdentifierWithOwner:owner repo:repo number:number];
}

+ (NSURL *)gitHubFilesURLForIssueIdentifier:(id)issueIdentifier {
    // https://github.com/realartists/shiphub-server/pull/166/files
    AuthAccount *account = [[[DataStore activeStore] auth] account];
    NSString *host = [account.ghHost stringByReplacingOccurrencesOfString:@"api." withString:@""] ?: @"github.com";
    
    NSString *URLStr = [NSString stringWithFormat:@"https://%@/%@/%@/pull/%@/files", host, [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], [issueIdentifier issueNumber]];
    return [NSURL URLWithString:URLStr];
}

- (NSURL *)gitHubFilesURL {
    return [[self class] gitHubFilesURLForIssueIdentifier:_issue.fullIdentifier];
}

- (BOOL)lightweightMergeUpdatedIssue:(Issue *)updatedIssue {
    NSArray *sortedReviews = [updatedIssue.reviews sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"identifier" ascending:NO]]];
    
    _myLastSubmittedReview = [sortedReviews firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"state != %ld AND user.identifier = %@", PRReviewStatePending, [[Account me] identifier]]];
    
    _myLastPendingReview = [sortedReviews firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"state = %ld AND user.identifier = %@", PRReviewStatePending, [[Account me] identifier]]];
    
    NSMutableArray *allSubmittedComments = [NSMutableArray new];
    [allSubmittedComments addObjectsFromArray:updatedIssue.prComments?:@[]];
    
    for (PRReview *r in updatedIssue.reviews) {
        if (r.state != PRReviewStatePending) {
            [allSubmittedComments addObjectsFromArray:r.comments?:@[]];
        }
    }
    
    [allSubmittedComments sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]];
    
    _prComments = allSubmittedComments;
    
    NSMutableDictionary *mInfo = [_info mutableCopy];
    mInfo[@"mergeable"] = updatedIssue.mergeable;
    mInfo[@"merged"] = updatedIssue.merged;
    _info = mInfo;
    
    NSString *issueHeadSha = updatedIssue.head[@"sha"];
    NSString *currentHeadSha = self.headSha;
    
    // check equality of head.sha
    // if it's the same, then lightweight update was possible
    // if it's changed, we're gonna have to do a new checkout
    return [NSObject object:issueHeadSha isEqual:currentHeadSha];
}

- (void)mergeComments:(NSArray<PRComment *> *)comments {
    NSMutableDictionary *lookup = [[NSDictionary lookupWithObjects:_prComments keyPath:@"identifier"] mutableCopy];
    for (PRComment *prc in comments) {
        lookup[prc.identifier] = prc;
    }
    NSArray *all = [[lookup allValues] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]];
    _prComments = all;
}

- (void)deleteComments:(NSArray<PRComment *> *)comments {
    NSDictionary *lookup = [NSDictionary lookupWithObjects:comments keyPath:@"identifier"];
    _prComments = [_prComments filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return lookup[[evaluatedObject identifier]] == nil;
    }]];
}

- (NSString *)bareRepoPath {
    return _dir;
}

- (NSString *)mergeTitle {
    return [NSString stringWithFormat:@"Merge pull request #%@ from %@/%@", _issue.number, _info[@"head"][@"repo"][@"full_name"], _info[@"head"][@"ref"]];
}

- (NSString *)mergeMessage {
    return _issue.title;
}

- (NSString *)headDescription {
    if ([_info[@"head"][@"repo"][@"full_name"] isEqualToString:_info[@"base"][@"repo"][@"full_name"]]) {
        return _info[@"head"][@"ref"];
    } else {
        return [NSString stringWithFormat:@"%@:%@", _info[@"head"][@"repo"][@"full_name"], _info[@"head"][@"ref"]];
    }
}

- (NSString *)baseDescription {
    return [NSString stringWithFormat:@"%@:%@", _info[@"base"][@"repo"][@"full_name"], _info[@"base"][@"ref"]];
}

- (BOOL)canMerge {
    id mergeable = _info[@"mergeable"];
    id merged = _info[@"merged"];
    
    BOOL isMergeable = [mergeable respondsToSelector:@selector(boolValue)] && [mergeable boolValue];
    BOOL isMerged = [merged respondsToSelector:@selector(boolValue)] && [merged boolValue];
    
    return !isMerged && isMergeable;
}

- (BOOL)isMerged {
    id merged = _info[@"merged"];
    
    BOOL isMerged = [merged respondsToSelector:@selector(boolValue)] && [merged boolValue];
    return isMerged;
}

- (void)performMergeWithMethod:(PRMergeStrategy)strat
                         title:(NSString *)title
                       message:(NSString *)message
                    completion:(void (^)(NSError *))completion
{
    NSParameterAssert(completion);
    
    if (![self canMerge]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([NSError shipErrorWithCode:ShipErrorCodeCannotMergePRError]);
        });
        return;
    }
    
    [[DataStore activeStore] mergePullRequest:_issue.fullIdentifier strategy:strat title:title message:message completion:^(Issue *issue, NSError *error) {
        completion(error);
    }];
}

- (NSError *)_revertMerge:(NSString *)mergeCommit prTemplate:(Issue *__autoreleasing *)prTemplate progress:(NSProgress *)progress
{
    Auth *auth = [[DataStore activeStore] auth];
    RequestPager *pager = [[RequestPager alloc] initWithAuth:auth];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    NSInteger operations = 0;
    
    __block NSDictionary *prInfo = nil;
    __block NSError *prError = nil;
    
    NSString *pullEndpoint = [NSString stringWithFormat:@"/repos/%@/pulls/%@", _issue.repository.fullName, _issue.number];
    [pager fetchSingleObject:[pager get:pullEndpoint] completion:^(NSDictionary *obj, NSError *err) {
        prError = err;
        prInfo = obj;
        dispatch_semaphore_signal(sema);
    }];
    operations++;
    
    while (operations != 0 && !progress.cancelled) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        operations--;
        progress.completedUnitCount += 1;
    }
    
    if (progress.cancelled) return [NSError cancelError];
    
    NSString *reposDir = [@"~/Library/RealArtists/Ship2/git" stringByExpandingTildeInPath];
    NSString *dir = [NSString stringWithFormat:@"%@/%@", reposDir, _issue.repository.fullName];
    
    NSError *error = nil;
    GitRepo *repo = [[self class] repoAtPath:dir error:&error];
    if (error) {
        return error;
    }
    
    NSString *remoteURLStr = prInfo[@"base"][@"clone_url"];
    
    if (remoteURLStr) {
        _githubRemoteURL = [NSURL URLWithString:remoteURLStr];
    }
    
    NSString *baseRefSpec = prInfo[@"base"][@"ref"];

    error = [repo fetchRemote:_githubRemoteURL username:[[[DataStore activeStore] auth] ghToken] password:@"x-oauth-basic" refs:@[baseRefSpec] progress:progress];
    
    if (error) return error;
    
    NSString *headBranch = prInfo[@"head"][@"ref"];
    if (![prInfo[@"head"][@"repo"][@"full_name"] isEqualToString:prInfo[@"base"][@"repo"][@"full_name"]]) {
        headBranch = [NSString stringWithFormat:@"%@/%@", prInfo[@"head"][@"repo"][@"full_name"], headBranch];
    }
    
    NSString *newBranch = [NSString stringWithFormat:@"revert-%@-%@", _issue.number, headBranch];
    error = [repo pushRemote:_githubRemoteURL username:[[[DataStore activeStore] auth] ghToken] password:@"x-oauth-basic" newBranchWithProposedName:newBranch revertingCommit:mergeCommit fromBranch:baseRefSpec progress:progress];
    
    if (error) return error;
    
    NSDictionary *headInfo = @{ @"repo" : @{ @"full_name" : _issue.repository.fullName }, @"ref" : newBranch };
    
    *prTemplate = [[Issue alloc] initPRWithTitle:[NSString stringWithFormat:@"Revert %@", _issue.title] repo:_issue.repository body:@"" baseInfo:prInfo[@"base"] headInfo:headInfo];
    
    return nil;
}

- (NSProgress *)revertMerge:(NSString *)mergeCommit withCompletion:(void (^)(Issue *prTemplate, NSError *error))completion
{
    NSParameterAssert(mergeCommit);
    NSParameterAssert(completion);
    
    NSProgress *progress = [NSProgress indeterminateProgress];
    progress.completedUnitCount = 0;
    progress.totalUnitCount = 1;
    progress.localizedDescription = NSLocalizedString(@"Preparing new branch for revert commit", nil);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        Issue *prTemplate = nil;
        NSError *err = [self _revertMerge:mergeCommit prTemplate:&prTemplate progress:progress];
        RunOnMain(^{
            completion(prTemplate, err);
        });
    });
    
    return progress;
}

@end

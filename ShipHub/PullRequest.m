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
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
#if DEBUG
    DebugLog(@"Loaded %td commits in %.3fs", _commits.count, (end-start));
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
    _headRefSpec = refSpec;
    
    // optimistically, see if we can find the PR without doing any network operations
    NSError *optimisticErr = [self loadSpanDiff];
    if (optimisticErr) {
        progress.localizedDescription = NSLocalizedString(@"Fetching git objects", nil);
        progress.completedUnitCount = 0;
        progress.totalUnitCount = -1;
        
        DebugLog(@"Have to fetch refSpec %@ from %@", refSpec, remoteURLStr);
        
        // See https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth
        error = [_repo fetchRemote:_githubRemoteURL username:[[[DataStore activeStore] auth] ghToken] password:@"x-oauth-basic" refs:@[refSpec] progress:progress];
        if (error) return error;
        
        error = [self loadSpanDiff];
        if (error) return error;
    } else {
        DebugLog(@"Loaded span diff without network op");
    }
    
    if (progress.cancelled) return [NSError cancelError];
    
    progress.localizedDescription = NSLocalizedString(@"Preparing diffs", nil);
    progress.totalUnitCount = 3;
    progress.completedUnitCount = 1;
    
    error = [self loadCommits];
    if (error) {
        ErrLog(@"Error loading commits %@", error);
        return error;
    }
    progress.completedUnitCount += 1;
    
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
    MetadataStore *ms = [[DataStore activeStore] metadataStore];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    __block NSDictionary *prInfo = nil;
    __block NSArray<PRComment *> *comments = nil;
    __block NSError *prError = nil;
    __block NSError *commentsError = nil;
    __block PRReview *review = nil;
    __block PRReview *submittedReview = nil;
    __block NSError *reviewError = nil;
    
    NSInteger operations = 0;
    
    NSString *pullEndpoint = [NSString stringWithFormat:@"/repos/%@/pulls/%@", _issue.repository.fullName, _issue.number];
    [pager fetchSingleObject:[pager get:pullEndpoint] completion:^(NSDictionary *obj, NSError *err) {
        prError = err;
        prInfo = obj;
        dispatch_semaphore_signal(sema);
    }];
    operations++;
    
    NSString *commentsEndpoint = [pullEndpoint stringByAppendingPathComponent:@"comments"];
    [pager fetchPaged:[pager get:commentsEndpoint] completion:^(NSArray *data, NSError *err) {
        comments = [data arrayByMappingObjects:^id(id obj) {
            return [[PRComment alloc] initWithDictionary:obj metadataStore:ms];
        }];
        commentsError = err;
        dispatch_semaphore_signal(sema);
    }];
    operations++;
    
    NSDictionary *reviewsHeaders = @{@"Accept":@"application/vnd.github.black-cat-preview+json"};
    NSString *reviewsEndpoint = [pullEndpoint stringByAppendingPathComponent:@"reviews"];
    
    [pager fetchPaged:[pager get:reviewsEndpoint params:nil headers:reviewsHeaders] completion:^(NSArray *data, NSError *err) {
        // See if we can find our own PRReview(s) in here
        
        NSArray *mySubmittedReviews = [data filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"state != 'PENDING' AND user.id = %@", [[Account me] identifier]]];
        mySubmittedReviews = [mySubmittedReviews arrayByMappingObjects:^id(id obj) {
            return [[PRReview alloc] initWithDictionary:obj comments:nil metadataStore:ms];
        }];
        mySubmittedReviews = [mySubmittedReviews sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"submittedAt" ascending:NO]]];
        submittedReview = [mySubmittedReviews firstObject];
        
        id myReview = [data firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"state = 'PENDING' AND user.id = %@", [[Account me] identifier]]];
        if (myReview) {
            NSString *reviewCommentsEndpoint = [reviewsEndpoint stringByAppendingFormat:@"/%@/comments", myReview[@"id"]];
            [pager fetchPaged:[pager get:reviewCommentsEndpoint params:nil headers:reviewsHeaders] completion:^(NSArray *rcs, NSError *err2) {
                if (rcs) {
                    rcs = [rcs arrayByMappingObjects:^id(id obj) {
                        return [[PendingPRComment alloc] initWithDictionary:obj metadataStore:ms];
                    }];
                    review = [[PRReview alloc] initWithDictionary:myReview comments:rcs metadataStore:ms];
                } else {
                    reviewError = err2;
                }
                dispatch_semaphore_signal(sema);
            }];
        } else {
            reviewError = err;
            dispatch_semaphore_signal(sema);
        }
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
    if (commentsError) return commentsError;
    if (reviewError) return reviewError;
    
    _info = prInfo;
    _prComments = comments;
    _myLastPendingReview = review;
    _myLastSubmittedReview = submittedReview;
    
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

- (BOOL)canMerge {
    id mergeable = _info[@"mergeable"];
    id merged = _info[@"merged"];
    
    BOOL isMergeable = [mergeable respondsToSelector:@selector(boolValue)] && [mergeable boolValue];
    BOOL isMerged = [merged respondsToSelector:@selector(boolValue)] && [merged boolValue];
    
    return !isMerged && isMergeable;
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
    
    NSMutableDictionary *msg = [NSMutableDictionary new];
    msg[@"sha"] = _spanDiff.headRev;
    switch (strat) {
        case PRMergeStrategyMerge:
            msg[@"merge_method"] = @"merge";
            break;
        case PRMergeStrategyRebase:
            msg[@"merge_method"] = @"rebase";
            break;
        case PRMergeStrategySquash:
            msg[@"merge_method"] = @"squash";
            break;
    }
    if (title) {
        msg[@"commit_title"] = title;
    }
    if (message) {
        msg[@"commit_message"] = message;
    }
    
    ServerConnection *conn = [[DataStore activeStore] serverConnection];
    NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/pulls/%@/merge", _issue.fullIdentifier.issueRepoFullName, _issue.fullIdentifier.issueNumber];
    
    NSDictionary *headers = @{ @"Accept": @"application/vnd.github.polaris-preview+json" };
    
    [conn perform:@"PUT" on:endpoint headers:headers body:msg completion:^(id jsonResponse, NSError *error) {
        if (error && [error.domain isEqualToString:ShipErrorDomain]) {
            NSInteger httpStatus = [error.userInfo[ShipErrorUserInfoHTTPResponseCodeKey] integerValue];
            if (httpStatus == 405) {
                error = [NSError shipErrorWithCode:ShipErrorCodeCannotMergePRError];
            } else if (httpStatus == 409) {
                error = [NSError shipErrorWithCode:ShipErrorCodeCannotMergePRError localizedMessage:@"Head branch was modified. Reload and try the merge again."];
            }
        }
        
        RunOnMain(^{
            completion(error);
        });
    }];
}

@end

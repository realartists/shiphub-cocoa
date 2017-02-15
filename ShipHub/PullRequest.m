//
//  PullRequest.m
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PullRequest.h"

#import "Auth.h"
#import "DataStore.h"
#import "Error.h"
#import "Extras.h"
#import "Issue.h"
#import "Repo.h"
#import "IssueIdentifier.h"
#import "ServerConnection.h"
#import "PRComment.h"

#import "GitDiff.h"
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

// runs on a background queue
- (NSError *)loadSpanDiff {
    NSError *err = nil;
    _spanDiff = [GitDiff diffWithRepo:_repo from:_info[@"base"][@"sha"] to:_info[@"head"][@"sha"] error:&err];
    if (err) return err;
    
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
    
    // optimistically, see if we can find the PR without doing any network operations
    NSError *optimisticErr = [self loadSpanDiff];
    if (optimisticErr) {
        NSString *remoteURLStr = _info[@"base"][@"repo"][@"clone_url"]; // want to use the base, as this is "origin"
        
        // See https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth
        NSURLComponents *comps = [NSURLComponents componentsWithString:remoteURLStr];
        comps.user = [[[DataStore activeStore] auth] ghToken];
        comps.password = @"x-oauth-basic";
        NSURL *remoteURL = comps.URL;
        
        // See https://help.github.com/articles/checking-out-pull-requests-locally/
        NSString *refSpec = [NSString stringWithFormat:@"pull/%@/head", _issue.number];
        
        DebugLog(@"Have to fetch refSpac %@ from %@", refSpec, remoteURLStr);
        
        error = [_repo fetchRemote:remoteURL refs:@[refSpec]];
        if (error) return error;
        
        error = [self loadSpanDiff];
        if (error) return error;
    } else {
        DebugLog(@"Loaded span diff without network op");
    }
    
    return nil;
}

// runs on a background queue
- (NSError *)checkoutWithProgress:(NSProgress *)progress {
    NSString *endpoint;
    ServerConnection *conn = [[DataStore activeStore] serverConnection];
    MetadataStore *ms = [[DataStore activeStore] metadataStore];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    __block NSDictionary *prInfo = nil;
    __block NSArray<PRComment *> *comments = nil;
    __block NSError *prError = nil;
    __block NSError *commentsError = nil;
    
    NSInteger operations = 0;
    
    endpoint = [NSString stringWithFormat:@"/repos/%@/pulls/%@", _issue.repository.fullName, _issue.number];
    [conn perform:@"GET" on:endpoint body:nil completion:^(id jsonResponse, NSError *error) {
        if ([jsonResponse isKindOfClass:[NSDictionary class]]) {
            prInfo = jsonResponse;
        } else {
            prError = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        if (!prError) {
            prError = error;
        }
        dispatch_semaphore_signal(sema);
    }];
    operations++;
    
    endpoint = [NSString stringWithFormat:@"/repos/%@/pulls/%@/comments", _issue.repository.fullName, _issue.number];
    [conn perform:@"GET" on:endpoint body:nil completion:^(id jsonResponse, NSError *error) {
        if ([jsonResponse isKindOfClass:[NSArray class]]) {
            comments = [jsonResponse arrayByMappingObjects:^id(id obj) {
                return [[PRComment alloc] initWithDictionary:obj metadataStore:ms];
            }];
        } else {
            commentsError = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        if (!commentsError) {
            commentsError = error;
        }
        dispatch_semaphore_signal(sema);
    }];
    operations++;
    
    // wait for responses
    while (operations != 0) {
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        operations--;
    }
    
    if (prError) return prError;
    if (commentsError) return commentsError;
    
    _info = prInfo;
    _prComments = comments;
    
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
    if (pathParts.count != 6 || ![pathParts[3] isEqualToString:@"pulls"] || ![pathParts[5] isEqualToString:@"files"]) {
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
    
    NSString *URLStr = [NSString stringWithFormat:@"https://%@/%@/%@/pulls/%@/files", host, [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], [issueIdentifier issueNumber]];
    return [NSURL URLWithString:URLStr];
}

- (NSURL *)gitHubFilesURL {
    return [[self class] gitHubFilesURLForIssueIdentifier:_issue.fullIdentifier];
}

@end

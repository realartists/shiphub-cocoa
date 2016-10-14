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

#import "GitDiff.h"
#import "GitRepo.h"

@interface PullRequest ()

@property NSArray *files;
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

- (void)dealloc {
    if (_dir) {
        NSString *dir = [_dir copy];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            [[NSFileManager defaultManager] removeItemAtPath:dir error:NULL];
        });
    }
}

// runs on a background queue
- (NSError *)loadSpanDiff {
    NSError *err = nil;
    _repo = [GitRepo repoAtPath:_dir error:&err];
    if (err) return err;
    
    _spanDiff = [GitDiff diffWithRepo:_repo from:_info[@"base"][@"sha"] to:_info[@"head"][@"sha"] error:&err];
    if (err) return err;
    
    return nil;
}

// runs on a background queue
- (NSError *)cloneWithProgress:(NSProgress *)progress {
    NSString *dirName = [NSString stringWithFormat:@"%@-XXXXXX", _issue.repository.name];
    NSString *dirTemplate = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
    char *dirStr = strdup([dirTemplate UTF8String]);
    mkdtemp(dirStr);
    _dir = [[NSString alloc] initWithBytesNoCopy:dirStr length:strlen(dirStr) encoding:NSUTF8StringEncoding freeWhenDone:YES];
    
    NSString *cloneURLStr = _info[@"head"][@"repo"][@"clone_url"];
    if (!cloneURLStr) {
        return [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
    }
    
    NSString *cloneRef = _info[@"head"][@"ref"];
    
    // See https://github.com/blog/1270-easier-builds-and-deployments-using-git-over-https-and-oauth
    NSURLComponents *comps = [NSURLComponents componentsWithString:cloneURLStr];
    comps.user = [[[DataStore activeStore] auth] ghToken];
    comps.password = @"x-oauth-basic";
    NSURL *cloneURL = comps.URL;
    
    NSString *supportPath = [[NSBundle mainBundle] sharedSupportPath];
    NSString *gitPath = @"/usr/bin/git"; //[supportPath stringByAppendingPathComponent:@"git"];
    NSString *cloneScriptPath = [supportPath stringByAppendingPathComponent:@"PartialClone.sh"];
    
    NSMutableArray *args = [@[cloneScriptPath,
                              gitPath,
                              [cloneURL description],
                              cloneRef] mutableCopy];
    
    for (NSDictionary *fileInfo in _files) {
        [args addObject:fileInfo[@"filename"]];
    }
    
    NSTask *task = [NSTask new];
    task.launchPath = @"/bin/bash";
    task.currentDirectoryPath = _dir;
    task.arguments = args;
    task.qualityOfService = NSQualityOfServiceUserInitiated;
    
    int result = [task launchAndWaitForTermination];
    if (result != 0) {
        return [NSError shipErrorWithCode:ShipErrorCodeGitCloneError];
    }
    
    NSError *err = [self loadSpanDiff];
    if (err) {
        return err;
    }
    
    
    return nil;
}

// runs on a background queue
- (NSError *)checkoutWithProgress:(NSProgress *)progress {
    NSString *endpoint;
    ServerConnection *conn = [[DataStore activeStore] serverConnection];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    __block NSArray *filesJSON = nil;
    __block NSError *filesError = nil;
    __block NSDictionary *prInfo = nil;
    __block NSError *prError = nil;
    
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
    
    endpoint = [endpoint stringByAppendingPathComponent:@"files"];
    [conn perform:@"GET" on:endpoint body:nil completion:^(id jsonResponse, NSError *error) {
        if ([jsonResponse isKindOfClass:[NSArray class]]) {
            filesJSON = jsonResponse;
        } else {
            filesError = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        if (!filesError) {
            filesError = error;
        }
        dispatch_semaphore_signal(sema);
    }];
    
    // wait for pr and files responses
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    if (prError) return prError;
    if (filesError) return filesError;
    
    _files = filesJSON;
    _info = prInfo;
    
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

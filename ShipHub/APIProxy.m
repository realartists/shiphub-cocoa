//
//  APIProxy.m
//  ShipHub
//
//  Created by James Howard on 4/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "APIProxy.h"

#import "Auth.h"
#import "DataStore.h"
#import "Error.h"
#import "Extras.h"
#import "Issue.h"
#import "IssueIdentifier.h"
#import "JSON.h"
#import "MetadataStore.h"
#import "Repo.h"
#import "Account.h"
#import "PRComment.h"

@interface ProxyRequest : NSMutableURLRequest

@property id bodyJSON;

@end

@interface APIProxy ()

@property (strong) NSDictionary *request;
@property (copy) APIProxyCompletion completion;

@end

@implementation APIProxy

#define BIND(request, boundSelector) \
    request : NSStringFromSelector(@selector(boundSelector))

+ (instancetype)proxyWithRequest:(NSDictionary *)request completion:(APIProxyCompletion)completion {
    
    APIProxy *p = [[[self class] alloc] init];
    p.completion = completion;
    p.request = request;
    
    return p;
}

- (void)dispatch {
    static NSDictionary *bindings;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bindings = [[self class] bindings];
    });
    
    NSURL *URL = [[NSURL alloc] initWithString:_request[@"url"]];
    ProxyRequest *request = [ProxyRequest requestWithURL:URL];
    
    NSDictionary *opts = _request[@"opts"];
    request.HTTPMethod = opts[@"method"];
    
    NSString *body = opts[@"body"];
    if (body) {
        request.bodyJSON = [NSJSONSerialization JSONObjectWithData:[body dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
    }
    
    NSDictionary *headers = opts[@"headers"];
    for (NSString *headerKey in headers) {
        [request addValue:headers[headerKey] forHTTPHeaderField:headerKey];
    }
    
    NSArray *pathComps = [[URL path] pathComponents];
    
    // walk bindings and find the best binding
    BOOL dispatched = NO;
    for (NSString *bind in bindings) {
        if ([bind hasPrefix:request.HTTPMethod]) {
            NSString *pathDesc = [bind substringFromIndex:request.HTTPMethod.length + 1];
            NSArray *pathDescComps = [pathDesc pathComponents];
            
            if (pathComps.count == pathDescComps.count) {
                
                BOOL match = YES;
                NSMutableArray *arguments = [NSMutableArray new];
                for (NSUInteger i = 0; i < pathComps.count; i++) {
                    NSString *actual = pathComps[i];
                    NSString *expected = pathDescComps[i];
                    
                    BOOL isArgument = [expected hasPrefix:@":"];
                    
                    if (!isArgument && ![expected isEqualToString:actual]) {
                        match = NO;
                        break;
                    }
                    
                    if (isArgument) {
                        [arguments addObject:actual];
                    }
                }
                
                if (match) {
                    SEL action = NSSelectorFromString(bindings[bind]);
                    NSMethodSignature *sig = [self methodSignatureForSelector:action];
                    NSAssert(sig != nil, @"Must have a real method bound to %@ : %@", bind, bindings[bind]);
                    
                    NSInvocation *ivk = [NSInvocation invocationWithMethodSignature:sig];
                    ivk.target = self;
                    ivk.selector = action;
                    
                    [ivk setArgument:&request atIndex:2];
                    NSInteger idx = 3;
                    for (id arg in arguments) {
                        [ivk setArgument:(void *)(&arg) atIndex:idx];
                        idx++;
                    }
                    
                    DebugLog(@"Dispatching %@", bindings[bind]);
                    [ivk invoke];
                    
                    dispatched = YES;
                }
            }
        }
        
        if (dispatched) {
            break;
        }
    }
    
    if (!dispatched) {
        [self dispatchGeneric:request];
    }
}

- (void)dispatchGeneric:(ProxyRequest *)request {
    DebugLog(@"%@", request);
    
    NSURL *URL = [request URL];
    NSURLComponents *comps = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    [comps setHost:[[[[DataStore activeStore] auth] account] shipHost]];
    
    [[[DataStore activeStore] auth] addAuthHeadersToRequest:request];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
    
        NSHTTPURLResponse *http = (id)response;
        
        if (http.statusCode >= 200 && http.statusCode < 400) {
            
            NSError *e = nil;
            id body = data.length ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&e] : nil;
            
            [self yield:body err:e];
            
        } else {
            
            if (![[[DataStore activeStore] auth] checkResponse:http]) {
                error = [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken];
            }
            
            [self yield:nil err:error];
        }
        
    }] resume];
}

- (void)yieldUpdatedIssue:(Issue *)issue {
    DebugLog(@"%@", issue);
    if (issue) {
        RunOnMain(^{
            APIProxyUpdatedIssue u = self.updatedIssueHandler;
            if (u) {
                u(issue);
            }
        });
    }
}

- (void)yield:(id)resp err:(NSError *)err {
    resp = [JSON stringifyObject:resp withNameTransformer:[JSON underbarsAndIDNameTransformer]];
    
    DebugLog(@"resp:%@ err:%@", resp, err);
    RunOnMain(^{
        APIProxyCompletion c = self.completion;
        if (c) {
            c(resp, err);
        }
        self.completion = nil;
    });
}

- (void)resume {
    [self dispatch];
}


#pragma mark - Request Handlers

/* To add a new request handler:
    1. Add an entry in the bindings dictionary
    2. Implement a method corresponding to the selector you're binding
*/
+ (NSDictionary *)bindings {
    return @{
     BIND(@"PATCH /repos/:owner/:repo/issues/comments/:commentIdentifier",
          editComment:owner:repo:commentIdentifier:),
     
     BIND(@"PATCH /repos/:owner/:repo/issues/:number",
          patchIssue:owner:repo:number:),
     
     BIND(@"DELETE /repos/:owner/:repo/issues/comments/:commentIdentifier",
          deleteComment:owner:repo:commentIdentifier:),
     
     BIND(@"POST /repos/:owner/:repo/issues/:number/comments",
          postComment:owner:repo:number:),
     
     BIND(@"POST /repos/:owner/:repo/issues",
          postIssue:owner:repo:),
     
     BIND(@"POST /repos/:owner/:repo/pulls",
          postPull:owner:repo:),
     
     BIND(@"POST /repos/:owner/:repo/issues/:number/reactions",
          postIssueReaction:owner:repo:issueNumber:),
     
     BIND(@"POST /repos/:owner/:repo/issues/comments/:id/reactions",
          postCommentReaction:owner:repo:commentIdentifier:),
     
     BIND(@"DELETE /reactions/:id",
          deleteReaction:reactionIdentifier:),
     
     BIND(@"GET /repos/:owner/:repo/issues/:number",
          getIssue:owner:repo:number:),
     
     BIND(@"GET /repos/:owner/:repo/issues/:number/events",
          getEvents:owner:repo:number:),
     
     BIND(@"GET /repos/:owner/:repo/issues/:number/events",
          getComments:owner:repo:number:),
     
     BIND(@"GET /user/repos",
          getRepos:),
     
     BIND(@"GET /repos/:owner/:repo/assignees",
          getAssignees:owner:repo:),
     
     BIND(@"GET /repos/:owner/:repo/milestones",
          getMilestones:owner:repo:),
     
     BIND(@"GET /repos/:owner/:repo/labels",
          getLabels:owner:repo:),
     
     BIND(@"POST /repos/:owner/:repo/pulls/:number/comments",
          postPRComment:owner:repo:number:),
     
     BIND(@"PATCH /repos/:owner/:repo/pulls/comments/:id",
          editPRComment:owner:repo:commentIdentifier:),
     
     BIND(@"DELETE /repos/:owner/:repo/pulls/comments/:id",
          deletePRComment:owner:repo:commentIdentifier:),
     
     BIND(@"POST /repos/:owner/:repo/pulls/:number/requested_reviewers",
          addRequestedReviewers:owner:repo:number:),
     
     BIND(@"DELETE /repos/:owner/:repo/pulls/:number/requested_reviewers",
          removeRequestedReviewers:owner:repo:number:),
     
     BIND(@"GET /user",
          getUser:)
     };
}

- (void)patchIssue:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number
{
    [[DataStore activeStore] patchIssue:request.bodyJSON issueIdentifier:[NSString issueIdentifierWithOwner:owner repo:repo number:number] completion:^(Issue *issue, NSError *error) {
        [self yieldUpdatedIssue:issue];
        [self yield:issue err:error];
    }];
}
         
- (void)editComment:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo commentIdentifier:(id)commentIdentifier
{
    NSNumber *commentNumber = [NSNumber numberWithLongLong:[commentIdentifier longLongValue]];
    [[DataStore activeStore] editComment:commentNumber body:request.bodyJSON[@"body"] inRepoFullName:[NSString stringWithFormat:@"%@/%@", owner, repo] completion:^(IssueComment *comment, NSError *error) {
        [self yield:comment err:error];
    }];
}

- (void)deleteComment:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo commentIdentifier:(id)commentIdentifier
{
    NSNumber *commentNumber = [NSNumber numberWithLongLong:[commentIdentifier longLongValue]];
    [[DataStore activeStore] deleteComment:commentNumber inRepoFullName:[NSString stringWithFormat:@"%@/%@", owner, repo] completion:^(NSError *error) {
        [self yield:nil err:error];
    }];
}

- (void)postComment:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number
{
    NSString *identifier = [NSString issueIdentifierWithOwner:owner repo:repo number:number];
    [[DataStore activeStore] postComment:request.bodyJSON[@"body"] inIssue:identifier completion:^(IssueComment *comment, NSError *error) {
        [self yield:comment err:error];
    }];
}

- (void)postPRComment:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number
{
    DataStore *ds = [DataStore activeStore];
    NSString *identifier = [NSString issueIdentifierWithOwner:owner repo:repo number:number];
    PRComment *comment = [[PRComment alloc] initWithDictionary:request.bodyJSON metadataStore:ds.metadataStore];
    [ds addSingleReviewComment:comment inIssue:identifier completion:^(PRComment *roundtrip, NSError *error) {
        [self yield:roundtrip err:error];
    }];
}

- (void)editPRComment:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo commentIdentifier:(id)commentIdentifier
{
    DataStore *ds = [DataStore activeStore];
    PRComment *edit = [PRComment new];
    edit.identifier = commentIdentifier;
    edit.body = [request.bodyJSON objectForKey:@"body"];
    
    NSString *issueIdentifier = [NSString issueIdentifierWithOwner:owner repo:repo number:@0 /* number doesn't matter */];
    
    [ds editReviewComment:edit inIssue:issueIdentifier completion:^(PRComment *roundtrip, NSError *error) {
        [self yield:roundtrip err:error];
    }];
}

- (void)deletePRComment:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo commentIdentifier:(id)commentIdentifier
{
    DataStore *ds = [DataStore activeStore];
    PRComment *c = [PRComment new];
    c.identifier = commentIdentifier;
    
    NSString *issueIdentifier = [NSString issueIdentifierWithOwner:owner repo:repo number:@0 /* number doesn't matter */];
    
    [ds deleteReviewComment:c inIssue:issueIdentifier completion:^(NSError *error) {
        [self yield:nil err:error];
    }];
}

- (void)postIssue:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo
{
    Repo *r = [self findRepoWithOwner:owner repo:repo];
    if (r) {
        [[DataStore activeStore] saveNewIssue:request.bodyJSON inRepo:r completion:^(Issue *issue, NSError *error) {
            [self yieldUpdatedIssue:issue];
            [self yield:issue err:error];
        }];
    } else {
        [self yield:nil err:[NSError shipErrorWithCode:ShipErrorCodeProblemDoesNotExist localizedMessage:[NSString stringWithFormat:NSLocalizedString(@"Could not locate repo %@/%@", nil), owner, repo]]];
    }
}

- (void)postPull:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo
{
    Repo *r = [self findRepoWithOwner:owner repo:repo];
    if (r) {
        [[DataStore activeStore] saveNewPullRequest:request.bodyJSON inRepo:r completion:^(Issue *issue, NSError *error) {
            [self yieldUpdatedIssue:issue];
            [self yield:issue err:error];
        }];
    } else {
        [self yield:nil err:[NSError shipErrorWithCode:ShipErrorCodeProblemDoesNotExist localizedMessage:[NSString stringWithFormat:NSLocalizedString(@"Could not locate repo %@/%@", nil), owner, repo]]];
    }
}

- (void)postIssueReaction:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo issueNumber:(id)number
{
    NSString *content = request.bodyJSON[@"content"];
    NSString *identifier = [NSString issueIdentifierWithOwner:owner repo:repo number:number];
    [[DataStore activeStore] postIssueReaction:content inIssue:identifier completion:^(Reaction *reaction, NSError *error) {
        [self yield:reaction err:error];
    }];
}

- (void)postCommentReaction:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo commentIdentifier:(NSString *)commentIdentifier
{
    NSNumber *commentNumber = [NSNumber numberWithLongLong:[commentIdentifier longLongValue]];
    NSString *content = request.bodyJSON[@"content"];
    [[DataStore activeStore] postCommentReaction:content inRepoFullName:[NSString stringWithFormat:@"%@/%@", owner, repo] inComment:commentNumber completion:^(Reaction *reaction, NSError *error) {
        [self yield:reaction err:error];
    }];
}

- (void)deleteReaction:(ProxyRequest *)request reactionIdentifier:(id)identifier
{
    NSNumber *reactionNumber = [NSNumber numberWithLongLong:[identifier longLongValue]];
    [[DataStore activeStore] deleteReaction:reactionNumber completion:^(NSError *error) {
        [self yield:nil err:error];
    }];
}

- (void)getIssue:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number
{
    NSString *identifier = [NSString issueIdentifierWithOwner:owner repo:repo number:number];
    [[DataStore activeStore] loadFullIssue:identifier completion:^(Issue *issue, NSError *error) {
        if (issue) {
            [self yield:issue err:nil];
        } else {
            [self dispatchGeneric:request];
        }
    }];
}

- (void)getEvents:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number
{
    [self dispatchGeneric:request];
}

- (void)getComments:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number
{
    [self dispatchGeneric:request];
}

- (void)getRepos:(ProxyRequest *)request
{
    [self yield:[[[DataStore activeStore] metadataStore] activeRepos] err:nil];
}

- (Repo *)findRepoWithOwner:(NSString *)owner repo:(NSString *)repo {
    MetadataStore *meta = [[DataStore activeStore] metadataStore];
    NSString *fullName = [NSString stringWithFormat:@"%@/%@", owner, repo];
    NSArray<Repo *> *repos = [meta activeRepos];
    repos = [repos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"fullName = %@", fullName] limit:1];
    return [repos firstObject];
}

- (void)getAssignees:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo
{
    MetadataStore *meta = [[DataStore activeStore] metadataStore];
    Repo *r = [self findRepoWithOwner:owner repo:repo];
    
    if (r) {
        [self yield:[meta assigneesForRepo:r] err:nil];
    } else {
        [self yield:@[] err:nil];
    }
}

- (void)getMilestones:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo
{
    MetadataStore *meta = [[DataStore activeStore] metadataStore];
    Repo *r = [self findRepoWithOwner:owner repo:repo];
    
    if (r) {
        [self yield:[meta activeMilestonesForRepo:r] err:nil];
    } else {
        [self yield:@[] err:nil];
    }
}

- (void)getLabels:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo
{
    MetadataStore *meta = [[DataStore activeStore] metadataStore];
    Repo *r = [self findRepoWithOwner:owner repo:repo];
    
    if (r) {
        [self yield:[meta labelsForRepo:r] err:nil];
    } else {
        [self yield:@[] err:nil];
    }
}

- (void)getUser:(ProxyRequest *)request
{
    [self yield:[Account me] err:nil];
}

- (void)addRequestedReviewers:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number {
    [[DataStore activeStore] addRequestedReviewers:request.bodyJSON[@"reviewers"] inIssue:[NSString issueIdentifierWithOwner:owner repo:repo number:number] completion:^(NSArray<NSString *> *reviewerLogins, NSError *error) {
        [self yield:reviewerLogins err:error];
    }];
}

- (void)removeRequestedReviewers:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number {
    [[DataStore activeStore] removeRequestedReviewers:request.bodyJSON[@"reviewers"] inIssue:[NSString issueIdentifierWithOwner:owner repo:repo number:number] completion:^(NSArray<NSString *> *reviewerLogins, NSError *error) {
        [self yield:reviewerLogins err:error];
    }];
}

@end

@implementation ProxyRequest

- (void)setHTTPBody:(NSData *)HTTPBody {
    _bodyJSON = [NSJSONSerialization JSONObjectWithData:HTTPBody options:0 error:NULL];
}

- (NSData *)HTTPBody {
    if (_bodyJSON) {
        return [NSJSONSerialization dataWithJSONObject:_bodyJSON options:0 error:NULL];
    }
    return nil;
}

@end

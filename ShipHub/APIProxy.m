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
#import "User.h"

@interface ProxyRequest : NSMutableURLRequest

@property id bodyJSON;

@end

@interface APIProxy ()

@property (strong) NSDictionary *request;
@property (strong) Issue *existingIssue;
@property (copy) APIProxyCompletion completion;

@end

@implementation APIProxy

#define BIND(request, boundSelector) \
    request : NSStringFromSelector(@selector(boundSelector))

+ (instancetype)proxyWithRequest:(NSDictionary *)request existingIssue:(Issue *)existingIssue completion:(APIProxyCompletion)completion {
    
    APIProxy *p = [[[self class] alloc] init];
    p.existingIssue = existingIssue;
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
            id body = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&e] : nil;
            
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
    RunOnMain(^{
        APIProxyUpdatedIssue u = self.updatedIssueHandler;
        if (u) {
            u(issue);
        }
    });
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
    [[DataStore activeStore] editComment:commentNumber body:request.bodyJSON[@"body"] inIssue:_existingIssue.fullIdentifier completion:^(IssueComment *comment, NSError *error) {
        [self yield:comment err:error];
    }];
}

- (void)deleteComment:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo commentIdentifier:(id)commentIdentifier
{
    NSNumber *commentNumber = [NSNumber numberWithLongLong:[commentIdentifier longLongValue]];
    [[DataStore activeStore] deleteComment:commentNumber inIssue:_existingIssue.fullIdentifier completion:^(NSError *error) {
        [self yield:nil err:error];
    }];
}

- (void)postComment:(ProxyRequest *)request owner:(NSString *)owner repo:(NSString *)repo number:(id)number
{
    [[DataStore activeStore] postComment:request.bodyJSON[@"body"] inIssue:_existingIssue.fullIdentifier completion:^(IssueComment *comment, NSError *error) {
        [self yield:comment err:error];
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
    [self yield:[User me] err:nil];
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

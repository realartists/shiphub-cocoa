//
//  RMEPRLoader.m
//  Reviewed By Me
//
//  Created by James Howard on 11/30/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEPRLoader.h"

#import "Auth.h"
#import "IssueIdentifier.h"
#import "Issue.h"
#import "ServerConnection.h"

#import "RMEIssue.h"
#import "RMERepo.h"

static NSString *const QueryPR;

@interface RMEPRLoader ()

@property Auth *auth;
@property dispatch_queue_t q;
@property id issueIdentifier;
@property NSMutableDictionary *result;
@property NSMutableSet<NSURLSessionDataTask *> *pendingTasks;

@end

@implementation RMEPRLoader

- (id)initWithIssueIdentifier:(id)issueIdentifier auth:(Auth *)auth queue:(dispatch_queue_t)queue;
{
    if (self = [super init]) {
        self.auth = auth;
        self.issueIdentifier = issueIdentifier;
        self.q = queue ?: dispatch_queue_create("RMEPRLoader", NULL);
        self.pendingTasks = [NSMutableSet new];
    }
    return self;
}

- (void)executeQuery:(NSString *)queryText variables:(NSDictionary *)vars completion:(void (^)(NSDictionary *result, NSError *error))completion
{
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = [[self.auth account] ghHost];
    comps.path = @"/graphql";
    
    NSMutableURLRequest *req = [[NSMutableURLRequest alloc] initWithURL:comps.URL];
    req.HTTPMethod = @"POST";
    [_auth addAuthHeadersToRequest:req];
    
    NSMutableDictionary *bodyDict = [NSMutableDictionary new];
    bodyDict[@"query"] = queryText;
    bodyDict[@"variables"] = vars;
    NSError *encodingErr = nil;
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&encodingErr];
    
    if (encodingErr) {
        ErrLog(@"%@", encodingErr);
        dispatch_async(_q, ^{
            completion(nil, encodingErr);
        });
        return;
    }
    
    DebugLog(@"Performing GraphQL: %@, vars: %@", queryText, vars);
    
    ServerConnection *conn = [[ServerConnection alloc] initWithAuth:_auth];
    __block NSURLSessionDataTask *task = nil;
    NSURLSessionDataTask *tmpTask =
    [conn perform:@"POST" on:@"/graphql" body:bodyDict completion:^(id jsonResponse, NSError *error) {
        dispatch_async(_q, ^{
            if (task) [_pendingTasks removeObject:task];
            if (error) {
                completion(nil, error);
            } else {
                NSDictionary *d = [jsonResponse objectForKey:@"data"];
                completion(d, nil);
            }
        });
    }];
    task = tmpTask;
}

- (void)start {
    NSAssert(self.completion != nil, @"Should have a completion set prior to starting");
    NSAssert([_pendingTasks count] == 0, @"Can't start twice");
    
    CFRetain((__bridge CFTypeRef)self);
    
    [self executeQuery:QueryPR variables:@{@"owner":[_issueIdentifier issueRepoOwner], @"name":[_issueIdentifier issueRepoName], @"number":[_issueIdentifier issueNumber]} completion:^(NSDictionary *result, NSError *error) {
        self.result = [result mutableCopy];
        if (error) {
            self.completion(nil, error);
            CFRelease((__bridge CFTypeRef)self);
        } else {
            [self pageResult];
        }
    }];
}

- (void)pageAssignable { }
- (void)pageReviews { }
- (void)fetchReactions { }

- (void)pageResult {
    [self pageAssignable];
    [self pageReviews];
    [self fetchReactions];
    
    if (_pendingTasks.count == 0) {
        // no more paging needed
        
        self.completion([self createIssue], nil);
    }
    
    CFRelease((__bridge CFTypeRef)self);
}

static NSDictionary *deleteNullsInDict(NSDictionary *d);

static NSArray *deleteNullsInArray(NSArray *a) {
    NSNull *null = [NSNull null];
    NSInteger i = 0;
    NSMutableArray *copy = nil;
    for (id v in a) {
        id repl = v;
        if (v == null) {
            repl = nil;
        } else if ([v isKindOfClass:[NSDictionary class]]) {
            repl = deleteNullsInDict(v);
        } else if ([v isKindOfClass:[NSArray class]]) {
            repl = deleteNullsInArray(v);
        }
        if (repl != v) {
            if (!copy) {
                copy = [[a subarrayWithRange:NSMakeRange(0, i)] mutableCopy];
            }
        }
        if (copy && repl) {
            [copy addObject:repl];
        }
        i++;
    }
    return copy ?: a;
}

static NSDictionary *deleteNullsInDict(NSDictionary *d) {
    NSNull *null = [NSNull null];
    NSMutableDictionary *copy = nil;
    for (id<NSCopying> key in d) {
        id val = d[key];
        id replVal = val;
        if (val == null) {
            replVal = nil;
        } else if ([val isKindOfClass:[NSDictionary class]]) {
            replVal = deleteNullsInDict(val);
        } else if ([val isKindOfClass:[NSArray class]]) {
            replVal = deleteNullsInArray(val);
        }
        if (replVal != val) {
            if (!copy) {
                copy = [d mutableCopy];
            }
            if (replVal) {
                copy[key] = replVal;
            } else {
                [copy removeObjectForKey:key];
            }
        }
    }
    return copy ?: d;
}

- (Issue *)createIssue {
    NSDictionary *cleanedGQL = deleteNullsInDict(self.result);
    RMERepo *repo = [[RMERepo alloc] initWithGraphQL:[cleanedGQL valueForKeyPath:@"repository"]];
    RMEIssue *issue = [[RMEIssue alloc] initWithGraphQL:[cleanedGQL valueForKeyPath:@"repository.pullRequest"] repository:repo];
    return issue;
}

@end

#define PAGEABLE_USERS \
@"      pageInfo {\n" \
@"        endCursor\n" \
@"        hasNextPage\n" \
@"      }\n" \
@"      edges {\n" \
@"        cursor\n" \
@"        node {\n" \
@"          login\n" \
@"          databaseId\n" \
@"          name\n" \
@"        }\n" \
@"      }\n"

#define PAGEABLE_REVIEW_COMMENTS \
@"              pageInfo {\n" \
@"                endCursor\n" \
@"                hasNextPage\n" \
@"              }\n" \
@"              edges {\n" \
@"                cursor\n" \
@"                node {\n" \
@"                  databaseId\n" \
@"                  author {\n" \
@"                    __typename\n" \
@"                    login\n" \
@"                    ... on User { databaseId name }\n" \
@"                    ... on Organization { databaseId  name }\n" \
@"                    ... on Bot { databaseId }\n" \
@"                  }\n" \
@"                  authorAssociation\n" \
@"                  body\n" \
@"                  commit {\n" \
@"                    oid\n" \
@"                  }\n" \
@"                  path\n" \
@"                  position\n" \
@"                  originalCommit {\n" \
@"                    oid\n" \
@"                  }\n" \
@"                  originalPosition\n" \
@"                  createdAt\n" \
@"                  diffHunk\n" \
@"                  lastEditedAt\n" \
@"                  pullRequestReview {\n" \
@"                    databaseId\n" \
@"                  }\n" \
@"                  replyTo {\n" \
@"                    databaseId\n" \
@"                  }\n" \
@"                }\n" \
@"              }\n" \

#define PAGEABLE_REVIEWS \
@"        pageInfo {\n" \
@"          endCursor\n" \
@"          hasNextPage\n" \
@"        }\n" \
@"        edges {\n" \
@"          cursor\n" \
@"          node {\n" \
@"            databaseId\n" \
@"            author {\n" \
@"              __typename\n" \
@"              login\n" \
@"              ... on User { databaseId name }\n" \
@"              ... on Organization { databaseId  name }\n" \
@"              ... on Bot { databaseId }\n" \
@"            }\n" \
@"            state\n" \
@"            createdAt\n" \
@"            submittedAt\n" \
@"            authorAssociation\n" \
@"            body\n" \
@"            commit {\n" \
@"              oid\n" \
@"            }\n" \
@"            comments(first:100) {\n" \
PAGEABLE_REVIEW_COMMENTS \
@"            }\n" \
@"          }\n" \
@"        }\n" \


static NSString *const QueryPR =
@"query($owner:String!, $name:String!, $number:Int!) {\n"
@"  rateLimit { cost nodeCount limit remaining resetAt }\n"
@"  repository(owner:$owner, name:$name) {\n"
@"    databaseId\n"
@"    name\n"
@"    nameWithOwner\n"
@"    isPrivate\n"
@"    owner {\n"
@"      __typename\n"
@"      login\n"
@"      ... on User { databaseId name }\n"
@"      ... on Organization { databaseId  name }\n"
@"    }\n"
@"    defaultBranchRef {\n"
@"      name\n"
@"    }\n"
@"    assignableUsers(first:100) {\n"
PAGEABLE_USERS
@"    }\n"
@"    pullRequest(number:$number) {\n"
@"      databaseId\n"
@"      number\n"
@"      body\n"
@"      title\n"
@"      closed\n"
@"      merged\n"
@"      state\n"
@"      mergeable\n"
@"      createdAt\n"
@"      updatedAt\n"
@"      mergedAt\n"
@"      locked\n"
@"      baseRef {\n"
@"        name\n"
@"        repository {\n"
@"          databaseId\n"
@"          name\n"
@"          nameWithOwner\n"
@"          defaultBranchRef {\n"
@"            name\n"
@"          }\n"
@"        }\n"
@"        target {\n"
@"          oid\n"
@"        }\n"
@"      }\n"
@"      headRef {\n"
@"        name\n"
@"        repository {\n"
@"          databaseId\n"
@"          name\n"
@"          nameWithOwner\n"
@"          defaultBranchRef {\n"
@"            name\n"
@"          }\n"
@"        }\n"
@"        target {\n"
@"          oid\n"
@"        }\n"
@"      }\n"
@"      mergeCommit {\n"
@"        oid\n"
@"      }\n"
@"      additions\n"
@"      deletions\n"
@"      changedFiles\n"
@"      author {\n"
@"        __typename\n"
@"        login\n"
@"        ... on User { databaseId name }\n"
@"        ... on Organization { databaseId  name }\n"
@"        ... on Bot { databaseId }\n"
@"      }\n"
@"      milestone {\n"
@"        number\n"
@"        title\n"
@"        description\n"
@"        dueOn\n"
@"        state\n"
@"      }\n"
@"      assignees(first:100) {\n"
PAGEABLE_USERS
@"      }\n"
@"      reviews(first:100) {\n"
PAGEABLE_REVIEWS
@"      }\n"
@"    }\n"
@"  }\n"
@"}\n";

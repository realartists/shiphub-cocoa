//
//  GHSyncConnection.m
//  ShipHub
//
//  Created by James Howard on 3/16/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GHSyncConnection.h"

#import "Auth.h"
#import "Error.h"
#import "Extras.h"
#import "IssueIdentifier.h"
#import "JSON.h"

#define POLL_INTERVAL 120.0

typedef NS_ENUM(NSInteger, SyncState) {
    SyncStateIdle,
    SyncStateRoot,
};

@interface GHSyncConnection () {
    dispatch_queue_t _q;
    dispatch_source_t _heartbeat;

    NSDictionary *_syncVersions;
    SyncState _state;
}

@end

@implementation GHSyncConnection

- (id)initWithAuth:(Auth *)auth {
    if (self = [super initWithAuth:auth]) {
        _q = dispatch_queue_create("GHSyncConnection", NULL);
        _heartbeat = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _q);
        
        __weak __typeof(self) weakSelf = self;
        dispatch_source_set_timer(_heartbeat, DISPATCH_TIME_NOW, POLL_INTERVAL * NSEC_PER_SEC, 10.0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(_heartbeat, ^{
            id strongSelf = weakSelf;
            [strongSelf heartbeat];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(POLL_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dispatch_resume(_heartbeat);
        });
    }
    return self;
}

- (void)syncWithVersions:(NSDictionary *)versions {
    dispatch_async(_q, ^{
        _syncVersions = [versions copy];
        [self heartbeat];
    });
}

- (void)heartbeat {
    dispatch_assert_current_queue(_q);
    
    if (_state == SyncStateIdle && _syncVersions) {
        [self startSync];
    }
}

- (NSMutableURLRequest *)get:(NSString *)endpoint {
    return [self get:endpoint params:nil];
}

- (NSMutableURLRequest *)get:(NSString *)endpoint params:(NSDictionary *)params {
    return [self get:endpoint params:params headers:nil];
}

- (NSMutableURLRequest *)get:(NSString *)endpoint params:(NSDictionary *)params headers:(NSDictionary *)headers {
    NSMutableURLRequest *req = nil;
    if ([endpoint hasPrefix:@"https://"]) {
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
    } else {
        if (![endpoint hasPrefix:@"/"]) {
            endpoint = [@"/" stringByAppendingString:endpoint];
        }
        NSURLComponents *c = [NSURLComponents new];
        c.scheme = @"https";
        c.host = self.auth.account.ghHost;
        c.path = endpoint;
        
        NSMutableArray *qps = [NSMutableArray new];
        for (NSString *k in [params allKeys]) {
            id v = params[k];
            [qps addObject:[NSURLQueryItem queryItemWithName:k value:[v description]]];
        }
        [qps addObject:[NSURLQueryItem queryItemWithName:@"per_page" value:@"100"]];
        c.queryItems = qps;
        
        
        req = [NSMutableURLRequest requestWithURL:[c URL]];
        NSAssert(req.URL, @"Request must have a URL (1)");
    }
    NSAssert(req.URL, @"Request must have a URL (2)");
    req.HTTPMethod = @"GET";

    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [req setValue:[NSString stringWithFormat:@"token %@", self.auth.ghToken] forHTTPHeaderField:@"Authorization"];

    for (NSString *key in [headers allKeys]) {
        [req setValue:headers[key] forHTTPHeaderField:key];
    }
    
    return req;
}

- (NSURLSessionDataTask *)jsonTask:(NSURLRequest *)request completion:(void (^)(id json, NSHTTPURLResponse *response, NSError *err))completion {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(_q, ^{
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (![self.auth checkResponse:response]) {
                completion(nil, http, [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken]);
                return;
            } else if (error) {
                completion(nil, http, error);
                return;
            }
            
            NSError *err = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if (err) {
                completion(nil, http, err);
                return;
            }
            
            completion(json, http, nil);
        });
    }];
    [task resume];
    return task;
}

- (NSArray<NSURLSessionDataTask *> *)tasks:(NSArray<NSURLRequest *>*)requests completion:(void (^)(NSArray<URLSessionResult *>* results))completion {
    NSArray<NSURLSessionDataTask *> *tasks = [[NSURLSession sharedSession] dataTasksWithRequests:requests completion:^(NSArray<URLSessionResult *> *results) {
        dispatch_async(_q, ^{
            completion(results);
        });
    }];
    // tasks are automatically resumed
    return tasks;
}

- (NSArray<NSURLSessionDataTask *> *)jsonTasks:(NSArray<NSURLRequest *>*)requests completion:(void (^)(NSArray *json, NSError *err))completion {
    return [self tasks:requests completion:^(NSArray<URLSessionResult *> *results) {
        NSError *anyError = nil;
        for (URLSessionResult *r in results) {
            NSInteger statusCode = ((NSHTTPURLResponse *)r.response).statusCode;
            anyError = r.error;
            if (![self.auth checkResponse:r.response]) {
                anyError = [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken];
            }
            if (!anyError && statusCode != 200) {
                anyError = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            if (anyError) break;
        }
        if (anyError) {
            completion(nil, anyError);
            return;
        }

        NSMutableArray *json = [NSMutableArray arrayWithCapacity:results.count];
        for (URLSessionResult *r in results) {
            id v = [r json];
            if (r.error) {
                completion(nil, r.error);
                return;
            }
            
            [json addObject:v];
        }
        
        completion(json, nil);
    }];
}

#if 0
 function pagedFetch(url) /* => Promise */ {
     var opts = { headers: { Authorization: "token " + debugToken }, method: "GET" };
     var initial = fetch(url, opts);
     return initial.then(function(resp) {
         var pages = []
         var link = resp.headers.get("Link");
         if (link) {
             var [next, last] = link.split(", ");
             var matchNext = next.match(/\<(.*?)\>; rel="next"/);
             var matchLast = last.match(/\<(.*?)\>; rel="last"/);
             console.log(matchNext);
             console.log(matchLast);
             if (matchNext && matchLast) {
                 var second = parseInt(matchNext[1].match(/page=(\d+)/)[1]);
                 var last = parseInt(matchLast[1].match(/page=(\d+)/)[1]);
                 console.log("second: " + second + " last: " + last);
                 for (var i = second; i <= last; i++) {
                     var pageURL = matchNext[1].replace(/page=\d+/, "page=" + i);
                     console.log("Adding pageURL: " + pageURL);
                     pages.push(fetch(pageURL, opts).then(function(resp) { return resp.json(); }));
                 }
             }
         }
         return Promise.all([resp.json()].concat(pages));
     }).then(function(pages) {
         return pages.reduce(function(a, b) { return a.concat(b); });
     });
 }
#endif

- (void)fetchPaged:(NSURLRequest *)rootRequest completion:(void (^)(NSArray *data, NSError *err))completion {
    NSParameterAssert(rootRequest);
    NSParameterAssert(completion);
    // Must first fetch the rootRequest and then can fetch each page
    DebugLog(@"%@", rootRequest);
    [self jsonTask:rootRequest completion:^(id first, NSHTTPURLResponse *response, NSError *err) {
        if (err) {
            completion(nil, err);
            return;
        }
        
        NSMutableArray *pageRequests = [NSMutableArray array];
        
        NSString *link = [response allHeaderFields][@"Link"];
        
        if (link) {
            NSString *next, *last;
            NSArray *comps = [link componentsSeparatedByString:@", "];
            next = [comps firstObject];
            last = [comps lastObject];
            
            NSTextCheckingResult *matchNext = [[[NSRegularExpression regularExpressionWithPattern:@"\\<(.*?)\\>; rel=\"next\"" options:0 error:NULL] matchesInString:next options:0 range:NSMakeRange(0, next.length)] firstObject];
            NSTextCheckingResult *matchLast = [[[NSRegularExpression regularExpressionWithPattern:@"\\<(.*?)\\>; rel=\"last\"" options:0 error:NULL] matchesInString:last options:0 range:NSMakeRange(0, last.length)] firstObject];
            
            if (matchNext && matchLast) {
                NSString *nextPageURLStr = [next substringWithRange:[matchNext rangeAtIndex:1]];
                NSString *lastPageURLStr = [last substringWithRange:[matchLast rangeAtIndex:1]];
                NSRegularExpression *pageExp = [NSRegularExpression regularExpressionWithPattern:@"page=(\\d+)$" options:0 error:NULL];
                NSTextCheckingResult *secondPageMatch = [[pageExp matchesInString:nextPageURLStr options:0 range:NSMakeRange(0, nextPageURLStr.length)] firstObject];
                NSTextCheckingResult *lastPageMatch = [[pageExp matchesInString:lastPageURLStr options:0 range:NSMakeRange(0, lastPageURLStr.length)] firstObject];
                
                if (secondPageMatch && lastPageMatch) {
                    NSInteger secondIdx = [[nextPageURLStr substringWithRange:[secondPageMatch rangeAtIndex:1]] integerValue];
                    NSInteger lastIdx = [[lastPageURLStr substringWithRange:[lastPageMatch rangeAtIndex:1]] integerValue];
                    
                    for (NSInteger i = secondIdx; i <= lastIdx; i++) {
                        NSString *pageURLStr = [nextPageURLStr stringByReplacingCharactersInRange:[secondPageMatch rangeAtIndex:1] withString:[NSString stringWithFormat:@"%td", i]];
                        [pageRequests addObject:[self get:pageURLStr
                                                   params:nil
                                                  headers:[rootRequest allHTTPHeaderFields]]];
                    }
                }
            }
        }
        
        if (pageRequests.count) {
            [self jsonTasks:pageRequests completion:^(NSArray *rest, NSError *restErr) {
                if (err) {
                    ErrLog(@"%@", err);
                    completion(nil, restErr);
                } else {
                    NSMutableArray *all = [first mutableCopy];
                    for (NSArray *page in rest) {
                        [all addObjectsFromArray:page];
                    }
                    DebugLog(@"%@ finished with %td pages: %tu items", rootRequest, 1+rest.count, all.count);
                    completion(all, nil);
                }
            }];
        } else {
            DebugLog(@"%@ finished with 1 page: %tu items", rootRequest, ((NSArray *)first).count);
            completion(first, nil);
        }
        
    }];
}


- (void)startSync {
    Trace();
    dispatch_assert_current_queue(_q);
    NSAssert(_state == SyncStateIdle, nil);
    
    if (self.auth.authState == AuthStateInvalid) {
        DebugLog(@"Not auth'd. Bailing out.");
        return;
    }
    
    _state = SyncStateRoot;
    
    [self fetchPaged:[self get:@"/user/repos"] completion:^(NSArray *repos, NSError *err) {
        if (err || repos.count == 0) {
            ErrLog(@"%@", err);
            _state = SyncStateIdle;
            return;
        }
        
        repos = [repos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"has_issues = YES"]];
        
        // now find all the valid assignees for each of the repos. these will be our set of users.
        NSMutableArray *assigneeRequests = [NSMutableArray new];
        for (NSDictionary *repo in repos) {
            NSString *assigneesEndpoint = [NSString stringWithFormat:@"/repos/%@/%@/assignees", repo[@"owner"][@"login"], repo[@"name"]];
            [assigneeRequests addObject:[self get:assigneesEndpoint]];
        }
        
        // additionally the orgs who own our repos are our set of orgs
        NSMutableArray *orgs = [NSMutableArray new];
        for (NSDictionary *repo in repos) {
            if ([repo[@"owner"][@"type"] isEqualToString:@"Organization"]) {
                [orgs addObject:repo[@"owner"]];
            }
        }
        NSArray *dedupedOrgs = [[NSDictionary lookupWithObjects:orgs keyPath:@"id"] allValues];
        
        [self tasks:assigneeRequests completion:^(NSArray<URLSessionResult *> *results) {
            NSMutableArray *assigneesForActiveRepos = [NSMutableArray new];
            NSMutableArray *activeRepos = [NSMutableArray new];
            NSUInteger i = 0;
            for (URLSessionResult *result in results) {
                id json = [result json];
                if (!result.error && ((NSHTTPURLResponse *)result.response).statusCode == 200) {
                    [assigneesForActiveRepos addObject:json];
                    [activeRepos addObject:repos[i]];
                } else {
                    // XXX: Ignore any repos in which we cannot fetch assignees.
                    DebugLog(@"Ignoring failed assignees response: %@", result);
                }
                i++;
            }

            // need to deduplicate assigness
            NSMutableArray *allAssignees = [NSMutableArray new];
            for (id assigneeGroup in assigneesForActiveRepos) {
                [allAssignees addObjectsFromArray:assigneeGroup];
            }
            NSDictionary *assigneesLookup = [NSDictionary lookupWithObjects:allAssignees keyPath:@"id"];
            NSArray *dedupedAssignees = [assigneesLookup allValues];
            
            NSMutableArray *reposWithAssignees = [NSMutableArray new];
            i = 0;
            for (NSDictionary *repo in activeRepos) {
                NSMutableDictionary *d = [repo mutableCopy];
                    d[@"assignees"] = [assigneesForActiveRepos[i] arrayByMappingObjects:^id(NSDictionary *obj) {
                        return obj[@"id"];
                    }];

                [reposWithAssignees addObject:d];
                i++;
            }
            
            // yield the users to the delegate
            [self yield:accountsWithRepos(dedupedAssignees, activeRepos) type:@"user" version:@{}];
            
            // Need to wait for orgs and milestones before we can yield repos.
            dispatch_group_t waitForOrgsAndMilestones = dispatch_group_create();
            
            // find the milestones for each repo
            __block NSArray *reposWithInfo = nil;
            dispatch_group_enter(waitForOrgsAndMilestones);
            [self findMilestonesAndLabels:reposWithAssignees completion:^(NSArray *rwi) {
                reposWithInfo = rwi;
                dispatch_group_leave(waitForOrgsAndMilestones);
            }];
            
            // now find the org membership
            dispatch_group_enter(waitForOrgsAndMilestones);
            [self orgMembership:dedupedOrgs repos:activeRepos validMembers:assigneesLookup completion:^{
                dispatch_group_leave(waitForOrgsAndMilestones);
            }];
            
            dispatch_group_notify(waitForOrgsAndMilestones, _q, ^{
                // yield the repos
                [self yield:reposWithInfo type:@"repo" version:@{}];
                
                [self findIssues:reposWithInfo];
            });
        }];
    }];
}

static id accountsWithRepos(NSArray *accounts, NSArray *repos) {
    NSMutableDictionary *partitionedRepos = [NSMutableDictionary new];
    for (NSDictionary *repo in repos) {
        NSMutableArray *l = partitionedRepos[repo[@"owner"][@"id"]];
        if (!l) {
            l = [NSMutableArray new];
            partitionedRepos[repo[@"owner"][@"id"]] = l;
        }
        [l addObject:repo[@"id"]];
    }
    NSMutableArray *augmented = [NSMutableArray arrayWithCapacity:accounts.count];
    for (NSDictionary *d in accounts) {
        NSMutableDictionary *m = [d mutableCopy];
        m[@"repos"] = partitionedRepos[d[@"id"]];
        [augmented addObject:m];
    }
    return augmented;
}

- (void)orgMembership:(NSArray *)dedupedOrgs repos:(NSArray *)repos validMembers:(NSDictionary *)users completion:(dispatch_block_t)completion {
    NSMutableArray *spideredOrgs = [NSMutableArray arrayWithCapacity:dedupedOrgs.count];
    __block BOOL failed = NO;
    for (NSDictionary *org in dedupedOrgs) {
        NSMutableDictionary *orgWithUsers = [org mutableCopy];
        NSString *memberEndpoint = [NSString stringWithFormat:@"orgs/%@/members", org[@"login"]];
        
        [self fetchPaged:[self get:memberEndpoint] completion:^(NSArray *data, NSError *err) {
            if (failed) {
                return;
            }
            if (err) {
                _state = SyncStateIdle;
                failed = YES;
                completion();
                return;
            }
            
            orgWithUsers[@"users"] = [data filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"id IN %@", [users allKeys]]];
            
            [spideredOrgs addObject:orgWithUsers];
            
            if (spideredOrgs.count == dedupedOrgs.count) {
                // can yield orgs
                [self yield:accountsWithRepos(spideredOrgs, repos) type:@"org" version:@{}];
                completion();
            }
        }];
    }
}

- (void)findMilestonesAndLabels:(NSArray *)repos completion:(void (^)(NSArray *rwi))completion {
    __block NSUInteger remaining = repos.count * 2;
    NSMutableArray *rwis = [NSMutableArray arrayWithCapacity:repos.count];
    
    dispatch_block_t done = ^{
        remaining--;
        if (remaining == 0) {
            completion(rwis);
        }
    };
    
    for (NSDictionary *repo in repos) {
        NSMutableDictionary *rwi = [repo mutableCopy];
        [rwis addObject:rwi];
        
        NSString *baseEndpoint = [NSString stringWithFormat:@"repos/%@/%@", repo[@"owner"][@"login"], repo[@"name"]];
        NSString *labelsEndpoint = [baseEndpoint stringByAppendingPathComponent:@"labels"];
        NSString *milestonesEndpoint = [baseEndpoint stringByAppendingPathComponent:@"milestones"];
        [self fetchPaged:[self get:labelsEndpoint] completion:^(NSArray *data, NSError *err) {
            rwi[@"labels"] = data;
            done();
        }];
        
        [self fetchPaged:[self get:milestonesEndpoint] completion:^(NSArray *data, NSError *err) {
            rwi[@"milestones"] = data;
            done();
        }];
    }
}

- (void)findIssues:(NSArray *)repos {
    // fetch all the issues per repo
    
    __block NSInteger remaining = repos.count;
    
    // XXX: This is truly awful since it doesn't stream and there's no progress ...
    // But this whole class is a gross hack that needs to die in a radioactive fire so ...
    
    for (NSDictionary *repo in repos) {
        // calculate the since date for our query
        
        NSString *versionField = [NSString stringWithFormat:@"%@.issue", repo[@"id"]];
        int64_t issuesSince = [_syncVersions[versionField] longLongValue];
        NSDate *since = [NSDate dateWithTimeIntervalSinceReferenceDate:(double)(issuesSince) / 1000.0];
        NSString *sinceStr = [since JSONString];
        
        DebugLog(@"Repo %@/%@ has versionField %@ and since %@", repo[@"owner"][@"login"], repo[@"name"], versionField, since);
        
        NSDictionary *params = @{ @"filter": @"all",
                                  @"since": sinceStr,
                                  @"state": @"all",
                                  @"sort": @"updated",
                                  @"direction": @"asc" };
        
        NSString *endpoint = [NSString stringWithFormat:@"repos/%@/%@/issues", repo[@"owner"][@"login"], repo[@"name"]];
        
        [self fetchPaged:[self get:endpoint params:params] completion:^(NSArray *data, NSError *err) {
            NSArray *issues = nil;
            
            if (data) {
                NSArray *issuesOnly = [data filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pull_request = nil OR pull_request = NO"]];
                
                if ([repo[@"name"] isEqualToString:@"shiphub-cocoa"]) {
                    DebugLog(@"%@", data);
                }
                
                issues = [issuesOnly arrayByMappingObjects:^id(id obj) {
                    NSMutableDictionary *issue = [obj mutableCopy];
                    issue[@"repository"] = repo[@"id"];
                    return issue;
                }];
                
                if ([issues count]) {
                    // calculate the max date in all of issues and that's our latest since str
                    NSString *maxDate = nil;
                    for (NSDictionary *issue in issues) {
                        NSString *created = issue[@"created_at"];
                        NSString *updated = issue[@"updated_at"];
                        
                        if (!maxDate || [created compare:maxDate] == NSOrderedDescending) {
                            maxDate = created;
                        }
                        
                        if (!maxDate || [updated compare:maxDate] == NSOrderedDescending) {
                            maxDate = updated;
                        }
                    }
                    
                    NSDictionary *version = @{ versionField: @([[NSDate dateWithJSONString:maxDate] timeIntervalSinceReferenceDate] * 1000)};
                    
                    [self yield:issues type:@"issue" version:version];
                }
            }
            
            remaining--;
            if (remaining == 0) {
                _state = SyncStateIdle;
            }
        }];
    }
}

- (void)yield:(NSArray *)json type:(NSString *)type version:(NSDictionary *)version {
    NSArray *syncObjs = [JSON parseObject:json withNameTransformer:[JSON githubToCocoaNameTransformer]];
    
    syncObjs = [syncObjs arrayByMappingObjects:^id(id obj) {
        SyncEntry *e = [SyncEntry new];
        e.action = SyncEntryActionSet;
        e.entityName = type;
        e.data = obj;
        return e;
    }];
    
    _syncVersions = [_syncVersions dictionaryByAddingEntriesFromDictionary:version] ?: version;
    
    [self.delegate syncConnection:self receivedEntries:syncObjs versions:_syncVersions progress:1.0];
}

- (void)updateIssue:(id)issueIdentifier {
    
    NSString *issueEndpoint = [NSString stringWithFormat:@"repos/%@/%@/issues/%@", [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], [issueIdentifier issueNumber]];
    NSString *timelineEndpoint = [issueEndpoint stringByAppendingPathComponent:@"timeline"];
    NSURLRequest *timelineRequest = [self get:timelineEndpoint
                                       params:nil
                                      headers:@{@"Accept" : @"application/vnd.github.mockingbird-preview"}];
    
    [self jsonTask:[self get:issueEndpoint] completion:^(id json, NSHTTPURLResponse *response, NSError *err) {
        if (err) {
            ErrLog(@"%@", err);
            return;
        }
        
        NSNumber *issueID = [json objectForKey:@"id"];
        
        [self yield:@[json] type:@"issue" version:0];
        
        [self fetchPaged:timelineRequest completion:^(NSArray *data, NSError *timelineErr) {
            if (!timelineErr) {
                NSArray *eventsAndComments = [data arrayByMappingObjects:^id(id obj) {
                    NSMutableDictionary *d = [obj mutableCopy];
                    d[@"issue"] = issueID;
                    return d;
                }];
                
                NSArray *comments = [eventsAndComments filteredArrayUsingPredicate:
                                         [NSPredicate predicateWithFormat:@"event == 'commented'"]];
                [self yield:comments type:@"comment" version:@{}];
                
                NSArray *crossReferencedEvents = [eventsAndComments filteredArrayUsingPredicate:
                                                  [NSPredicate predicateWithFormat:@"event == %@", @"cross-referenced"]];
                NSMutableArray *referencedAndCommitEvents = [[eventsAndComments filteredArrayUsingPredicate:
                                                              [NSPredicate predicateWithFormat:@"event IN {'referenced', 'closed'}"]] mutableCopy];
                NSArray *allOtherEvents = [eventsAndComments filteredArrayUsingPredicate:
                                           [NSPredicate predicateWithFormat:@"NOT event IN {'referenced', 'cross-referenced', 'commented', 'closed'}"]];
                [self yield:allOtherEvents type:@"event" version:@{}];


                NSMutableArray *commitRequests = [NSMutableArray array];
                NSMutableArray *commmitRequestsToIndex = [NSMutableArray array];
                for (NSInteger i = 0; i < referencedAndCommitEvents.count; i++) {
                    NSDictionary *item = referencedAndCommitEvents[i];
                    if (item[@"commit_id"] && (item[@"commit_id"] != [NSNull null])) {
                        NSString *commitURL = item[@"commit_url"];
                        NSAssert(commitURL, @"should have commit URL");
                        [commitRequests addObject:[self get:commitURL]];
                        [commmitRequestsToIndex addObject:@(i)];
                    }
                }

                [self jsonTasks:commitRequests completion:^(NSArray *commitResults, NSError *commitError){
                    if (!commitError) {
                        for (NSInteger i = 0; i < commitRequests.count; i++) {
                            NSInteger eventIndex = [commmitRequestsToIndex[i] integerValue];
                            referencedAndCommitEvents[eventIndex] = [referencedAndCommitEvents[eventIndex] mutableCopy];
                            referencedAndCommitEvents[eventIndex][@"ship_commit_message"] = commitResults[i][@"commit"][@"message"];

                            NSDictionary *author = commitResults[i][@"author"];
                            // "author" field will only be populated if author's email maps to a GitHub user.
                            if ([author isKindOfClass:[NSDictionary class]]) {
                                referencedAndCommitEvents[eventIndex][@"ship_commit_author"] =
                                @{
                                  @"login" : commitResults[i][@"author"][@"login"],
                                  @"avatar_url" : commitResults[i][@"author"][@"avatar_url"],
                                  @"id" : commitResults[i][@"author"][@"id"],
                                  };
                            }
                        }
                        [self yield:referencedAndCommitEvents type:@"event" version:@{}];
                    }
                }];

                NSMutableArray *requests = [NSMutableArray array];
                NSMutableArray *requestsToIndex = [NSMutableArray array];
                for (NSInteger i = 0; i < crossReferencedEvents.count; i++) {
                    NSDictionary *item = crossReferencedEvents[i];
                    
                    if ([item[@"event"] isEqualToString:@"cross-referenced"]) {
                        NSString *sourceURL = item[@"source"][@"url"];
                        NSAssert(sourceURL, @"should have source URL");
                        NSURLRequest *request = [self get:sourceURL];
                        [requests addObject:request];
                        [requestsToIndex addObject:@(i)];
                    }
                }
                
                [self jsonTasks:requests completion:^(NSArray *results, NSError *resultsError){
                    if (!resultsError) {
                        NSMutableArray *prInfoRequests = [NSMutableArray array];
                        NSMutableArray *prInfoRequestsToIndex = [NSMutableArray array];

                        for (NSInteger i = 0; i < results.count; i++) {
                            NSInteger eventIndex = [requestsToIndex[i] integerValue];
                            NSDictionary *issue = results[i];
                            NSMutableDictionary *event = crossReferencedEvents[eventIndex];

                            event[@"ship_issue_state"] = issue[@"state"];
                            event[@"ship_issue_title"] = issue[@"title"];
                            event[@"ship_is_pull_request"] = @(issue[@"pull_request"] != nil);

                            // HACK: GitHub doesn't give an 'id' field for cross-referenced issues.  For now, we'll
                            // fudge one using a combination of (current issue ID, referencing issue ID).
                            //
                            // We should consider switching our ID columns to be strings so we can do stuff like
                            // "<referencedIssueID>_<referencingIssueID>".  That way, we'll have no chance of collision
                            // w/ a GitHub ID.
                            NSNumber *referencingIssueID = issue[@"id"];
                            event[@"id"] = [NSNumber numberWithLongLong:
                                            ([issueID longLongValue] << 32) | [referencingIssueID longLongValue]];
                            
                            if (issue[@"pull_request"]) {
                                NSURLRequest *prInfoRequest = [self get:issue[@"pull_request"][@"url"]];
                                [prInfoRequests addObject:prInfoRequest];
                                [prInfoRequestsToIndex addObject:@(eventIndex)];
                            }
                        }
                        
                        [self jsonTasks:prInfoRequests completion:^(NSArray *prInfoResults, NSError *prInfoResultsError){
                            if (!prInfoResultsError) {
                                for (NSInteger i = 0; i < prInfoResults.count; i++) {
                                    NSInteger eventIndex = [prInfoRequestsToIndex[i] integerValue];
                                    NSDictionary *pr = prInfoResults[i];
                                    NSMutableDictionary *event = crossReferencedEvents[eventIndex];

                                    event[@"ship_pull_request_merged"] = pr[@"merged"];
                                }
                                
                                [self yield:crossReferencedEvents type:@"event" version:@{}];
                            }
                        }];
                    }
                }];
            }
        }];
    }];
}

@end

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
#import "RequestPager.h"

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
    
    RequestPager *_pager;
}

@end

@implementation GHSyncConnection

- (id)initWithAuth:(Auth *)auth {
    if (self = [super initWithAuth:auth]) {
        _q = dispatch_queue_create("GHSyncConnection", NULL);
        _pager = [[RequestPager alloc] initWithAuth:auth queue:_q];
        
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

- (void)startSync {
    Trace();
    dispatch_assert_current_queue(_q);
    NSAssert(_state == SyncStateIdle, nil);
    
    if (self.auth.authState == AuthStateInvalid) {
        DebugLog(@"Not auth'd. Bailing out.");
        return;
    }
    
    [self.delegate syncConnection:self didReceiveBillingUpdate:@{ @"mode" : @"paid" }];
    
    _state = SyncStateRoot;
    
    [_pager fetchPaged:[_pager get:@"/user/repos"] completion:^(NSArray *repos, NSError *err) {
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
            [assigneeRequests addObject:[_pager get:assigneesEndpoint]];
        }
        
        // additionally the orgs who own our repos are our set of orgs
        NSMutableArray *orgs = [NSMutableArray new];
        for (NSDictionary *repo in repos) {
            if ([repo[@"owner"][@"type"] isEqualToString:@"Organization"]) {
                [orgs addObject:repo[@"owner"]];
            }
        }
        NSArray *dedupedOrgs = [[NSDictionary lookupWithObjects:orgs keyPath:@"id"] allValues];
        
        [_pager tasks:assigneeRequests completion:^(NSArray<URLSessionResult *> *results) {
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
    if (dedupedOrgs.count == 0) {
        completion();
        return;
    }
    for (NSDictionary *org in dedupedOrgs) {
        NSMutableDictionary *orgWithUsers = [org mutableCopy];
        NSString *memberEndpoint = [NSString stringWithFormat:@"orgs/%@/members", org[@"login"]];
        
        [_pager fetchPaged:[_pager get:memberEndpoint] completion:^(NSArray *data, NSError *err) {
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
    __block NSUInteger remaining = repos.count * 4;
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
        NSString *projectsEndpoint = [baseEndpoint stringByAppendingPathComponent:@"projects"];
        
        [self findIssueTemplate:repo completion:^(NSString *template, NSError *err) {
            if (template) {
                rwi[@"issue_template"] = template;
            } else {
                rwi[@"issue_template"] = [NSNull null];
            }
            done();
        }];
        
        [_pager fetchPaged:[_pager get:labelsEndpoint] completion:^(NSArray *data, NSError *err) {
            rwi[@"labels"] = data;
            done();
        }];
        
        [_pager fetchPaged:[_pager get:projectsEndpoint params:nil headers:@{@"Accept":@"application/vnd.github.inertia-preview+json"}] completion:^(NSArray *data, NSError *err) {
            rwi[@"projects"] = [data arrayByMappingObjects:^id(id obj) {
                NSMutableDictionary *proj = [obj mutableCopy];
                proj[@"repository"] = repo[@"id"];
                return proj;
            }];
            done();
        }];
        
        [_pager fetchPaged:[_pager get:milestonesEndpoint params:@{@"state": @"all"}] completion:^(NSArray *data, NSError *err) {
            rwi[@"milestones"] = [data arrayByMappingObjects:^id(id obj) {
                NSMutableDictionary *mile = [obj mutableCopy];
                mile[@"repository"] = repo[@"id"];
                return mile;
            }];
            done();
        }];
    }
}

- (void)findIssueTemplate:(NSDictionary *)repo completion:(void (^)(NSString *template, NSError *err))completion {
    NSArray *paths = @[@".github/ISSUE_TEMPLATE.md",
                       @".github/ISSUE_TEMPLATE",
                       @"ISSUE_TEMPLATE.md",
                       @"ISSUE_TEMPLATE"];
    
    NSArray *endpoints = [paths arrayByMappingObjects:^id(id path) {
        return [NSString stringWithFormat:@"repos/%@/contents/%@", repo[@"full_name"], path];
    }];
    
    NSDictionary *headers = @{@"Accept":@"application/vnd.github.VERSION.raw"};
    NSArray *requests = [endpoints arrayByMappingObjects:^id(id endpoint) {
        return [_pager get:endpoint params:nil headers:headers];
    }];
    
    [_pager tasks:requests completion:^(NSArray<URLSessionResult *> *results) {
        
        for (URLSessionResult *result in results) {
            NSHTTPURLResponse *http = (id)(result.response);
            if (http.statusCode == 200 && result.data.length > 0) {
                NSString *template = [[NSString alloc] initWithData:result.data encoding:NSUTF8StringEncoding];
                completion(template, nil);
                return;
            }
        }
        
        completion(nil, nil /* it's not an error not to have a template */);
    }];
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
        
        [_pager fetchPaged:[_pager get:endpoint params:params headers:@{ @"Accept" : @"application/vnd.github.squirrel-girl-preview"}] completion:^(NSArray *data, NSError *err) {
            NSArray *issues = nil;
            
            if (data) {
                issues = [data arrayByMappingObjects:^id(id obj) {
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
    NSString *commentReactionsBase = [issueEndpoint stringByDeletingLastPathComponent];
    NSString *timelineEndpoint = [issueEndpoint stringByAppendingPathComponent:@"timeline"];
    NSURLRequest *timelineRequest = [_pager get:timelineEndpoint
                                       params:nil
                                      headers:@{@"Accept" : @"application/vnd.github.mockingbird-preview"}];
    
    NSDictionary *reactionsHeaders = @{@"Accept" : @"application/vnd.github.squirrel-girl-preview"};
    NSString *reactionsEndpoint = [issueEndpoint stringByAppendingPathComponent:@"reactions"];
    NSURLRequest *reactionsRequest = [_pager get:reactionsEndpoint
                                          params:nil
                                         headers:reactionsHeaders];
    
    [_pager jsonTask:[_pager get:issueEndpoint params:nil headers:@{ @"Accept" : @"application/vnd.github.squirrel-girl-preview"}] completion:^(id json, NSHTTPURLResponse *response, NSError *err) {
        if (err || response.statusCode != 200) {
            ErrLog(@"%@", err);
            return;
        }
        
        NSNumber *issueID = [json objectForKey:@"id"];
        
        [self yield:@[json] type:@"issue" version:0];
        
        [_pager fetchPaged:reactionsRequest completion:^(NSArray *data, NSError *reactionsErr) {
            if (!reactionsErr) {
                NSArray *reactions = [data arrayByMappingObjects:^id(id obj) {
                    NSMutableDictionary *d = [obj mutableCopy];
                    d[@"issue"] = issueID;
                    return d;
                }];
                [self yield:reactions type:@"reaction" version:@{}];
            }
        }];
        
        [_pager fetchPaged:timelineRequest completion:^(NSArray *data, NSError *timelineErr) {
            if (!timelineErr) {
                NSArray *eventsAndComments = [data arrayByMappingObjects:^id(id obj) {
                    NSMutableDictionary *d = [obj mutableCopy];
                    d[@"issue"] = issueID;
                    return d;
                }];
                
                NSArray *comments = [eventsAndComments filteredArrayUsingPredicate:
                                         [NSPredicate predicateWithFormat:@"event == 'commented'"]];
                [self yield:comments type:@"comment" version:@{}];
                
                NSArray *commentReactionsRequests = [comments arrayByMappingObjects:^id(NSDictionary *obj) {
                    NSString *commentId = obj[@"id"];
                    NSString *commentReactionsEndpoint = [NSString stringWithFormat:@"%@/comments/%@/reactions", commentReactionsBase, commentId];
                    return [_pager get:commentReactionsEndpoint params:nil headers:reactionsHeaders];
                }];
                
                [_pager jsonTasks:commentReactionsRequests completion:^(NSArray *commentReactions, NSError *commentReactionsErr) {
                    if (!commentReactionsErr) {
                        NSMutableArray *reactionsToYield = [NSMutableArray new];
                        for (NSUInteger i = 0; i < commentReactions.count; i++) {
                            NSDictionary *comment = comments[i];
                            NSNumber *commentID = comment[@"id"];
                            NSArray *r = commentReactions[i];
                            r = [r arrayByMappingObjects:^id(NSDictionary *obj) {
                                return [obj dictionaryByAddingEntriesFromDictionary:@{@"comment" : commentID}];
                            }];
                            [reactionsToYield addObjectsFromArray:r];
                        }
                        [self yield:reactionsToYield type:@"reaction" version:@{}];
                    }
                }];
                
                NSArray *crossReferencedEvents = [eventsAndComments filteredArrayUsingPredicate:
                                                  [NSPredicate predicateWithFormat:@"event == %@", @"cross-referenced"]];
                NSMutableArray *referencedAndCommitEvents = [[eventsAndComments filteredArrayUsingPredicate:
                                                              [NSPredicate predicateWithFormat:@"event IN {'referenced', 'closed'}"]] mutableCopy];
                NSArray *allOtherEvents = [eventsAndComments filteredArrayUsingPredicate:
                                           [NSPredicate predicateWithFormat:@"NOT event IN {'referenced', 'cross-referenced', 'commented', 'closed'} AND id != nil"]];
                [self yield:allOtherEvents type:@"event" version:@{}];


                NSMutableArray *commitRequests = [NSMutableArray array];
                NSMutableArray *commmitRequestsToIndex = [NSMutableArray array];
                for (NSInteger i = 0; i < referencedAndCommitEvents.count; i++) {
                    NSDictionary *item = referencedAndCommitEvents[i];
                    if (item[@"commit_id"] && (item[@"commit_id"] != [NSNull null])) {
                        NSString *commitURL = item[@"commit_url"];
                        NSAssert(commitURL, @"should have commit URL");
                        [commitRequests addObject:[_pager get:commitURL]];
                        [commmitRequestsToIndex addObject:@(i)];
                    }
                }

                [_pager jsonTasks:commitRequests completion:^(NSArray *commitResults, NSError *commitError){
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
                        NSURLRequest *request = [_pager get:sourceURL];
                        [requests addObject:request];
                        [requestsToIndex addObject:@(i)];
                    }
                }
                
                [_pager jsonTasks:requests completion:^(NSArray *results, NSError *resultsError){
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
                                NSURLRequest *prInfoRequest = [_pager get:issue[@"pull_request"][@"url"]];
                                [prInfoRequests addObject:prInfoRequest];
                                [prInfoRequestsToIndex addObject:@(eventIndex)];
                            }
                        }
                        
                        [_pager jsonTasks:prInfoRequests completion:^(NSArray *prInfoResults, NSError *prInfoResultsError){
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

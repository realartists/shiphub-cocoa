//
//  GHNotificationManager.m
//  ShipHub
//
//  Created by James Howard on 7/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GHNotificationManager.h"

#import "Auth.h"
#import "Error.h"
#import "JSON.h"
#import "IssueIdentifier.h"
#import "RequestPager.h"
#import "Extras.h"
#import "DataStore.h"

#import "LocalNotification.h"
#import "LocalIssue.h"
#import "LocalRepo.h"
#import "LocalAccount.h"

@interface DataStore (Friend)

@property Auth *auth;

@end

@interface GHNotificationManager ()

@property NSManagedObjectContext *moc;
@property dispatch_queue_t q;
@property dispatch_source_t timer;
@property Auth *auth;
@property NSMutableSet *pendingIssues;
@property NSDate *lastUpdate;
@property RequestPager *pager;

@end

@implementation GHNotificationManager

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)ctx auth:(Auth *)auth store:(DataStore *)store {
    if (self = [super init]) {
        self.moc = ctx;
        self.auth = auth;
        self.store = store;
        
        _q = dispatch_queue_create("GHNotificationManager", NULL);
        
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _q);
        
        __weak __typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(_timer, ^{
            id strongSelf = weakSelf;
            [strongSelf timerFired];
        });
        dispatch_resume(_timer);
        
        _pager = [[RequestPager alloc] initWithAuth:auth queue:_q];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mocDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:nil];
        
        [self discoverPendingIssues];
        [self discoverLastUpdateAndStartPolling];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)timerFired {
    [self poll];
}

- (void)scheduleTimerWithInterval:(NSTimeInterval)interval {
    DebugLog(@"%f", interval);
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, interval * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 1 * NSEC_PER_SEC);
}

- (void)poll {
    Trace();
    
    dispatch_assert_current_queue(_q);
    
    NSMutableURLRequest *request = [_pager get:@"/notifications"];
    // bypass caching, since the GitHub Last-Modified caching system is broken :(
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [_pager fetchPaged:request headersCompletion:^(NSArray *data, NSDictionary *respHeaders, NSError *err) {
        if (!err) {
            NSMutableArray *records = [NSMutableArray new];
            for (NSDictionary *note in data) {
                NSDictionary *subject = note[@"subject"];
                
                if (![subject[@"type"] isEqualToString:@"Issue"]) {
                    continue;
                }
                
                NSMutableDictionary *record = [NSMutableDictionary new];
                
                if (subject[@"latest_comment_url"]) {
                    int64_t commentIdentifier = [[subject[@"latest_comment_url"] lastPathComponent] longLongValue];
                    if (commentIdentifier != 0) {
                        record[@"commentIdentifier"] = @(commentIdentifier);
                    }
                }
                
                NSString *issueNumber = [subject[@"url"] lastPathComponent];
                NSString *repoName = note[@"repository"][@"full_name"];
                
                record[@"issueFullIdentifier"] = [NSString stringWithFormat:@"%@#%@", repoName, issueNumber];
                
                record[@"reason"] = note[@"reason"];
                record[@"unread"] = note[@"unread"];
                
                record[@"lastReadAt"] = note[@"last_read_at"];
                record[@"updatedAt"] = note[@"updated_at"];
                record[@"identifier"] = @([note[@"id"] longLongValue]);
                
                [records addObject:record];
            }
            
            NSInteger pollInterval = [respHeaders[@"X-Poll-Interval"] integerValue];
            if (pollInterval == 0) pollInterval = 60;
            
            [self scheduleTimerWithInterval:(NSTimeInterval)pollInterval];
            
            [self writeRecords:records];
        } else {
            ErrLog(@"%@", err);
        }
    }];
}

- (void)writeRecords:(NSArray *)records {
    DebugLog(@"%@", records);
    
    if ([records count] == 0) return;
    
    [_moc performBlock:^{
        NSError *err = nil;
        
        NSMutableSet *issueIdentifiers = [NSMutableSet setWithCapacity:records.count];
        NSMutableSet *noteIdentifiers = [NSMutableSet setWithCapacity:records.count];
        
        for (NSDictionary *record in records) {
            [issueIdentifiers addObject:record[@"issueFullIdentifier"]];
            [noteIdentifiers addObject:record[@"identifier"]];
        }
    
        NSPredicate *identifiersPredicate = [_store predicateForIssueIdentifiers:[issueIdentifiers allObjects]];
        
        NSFetchRequest *issuesFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
        issuesFetch.predicate = identifiersPredicate;
        
        NSArray *issues = [_moc executeFetchRequest:issuesFetch error:&err];
        if (err) ErrLog(@"%@", err);
        err = nil;
        NSDictionary *issuesLookup = [NSDictionary lookupWithObjects:issues keyPath:@"fullIdentifier"];
        
        NSFetchRequest *noteFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
        NSArray *notes = [_moc executeFetchRequest:noteFetch error:&err];
        if (err) ErrLog(@"%@", err);
        
        NSDictionary *notesLookup = [NSDictionary lookupWithObjects:notes keyPath:@"identifier"];
        
        NSMutableSet *pending = [NSMutableSet new];
        
        for (NSDictionary *record in records) {
            id identifier = record[@"identifier"];
            LocalNotification *note = notesLookup[identifier];
            if (!note) {
                note = [NSEntityDescription insertNewObjectForEntityForName:@"LocalNotification" inManagedObjectContext:_moc];
            }
            [note mergeAttributesFromDictionary:record onlyIfChanged:YES];
            
            id issueFullIdentifier = record[@"issueFullIdentifier"];
            LocalIssue *issue = issuesLookup[issueFullIdentifier];
            if (issue) {
                if (!note.issue || ![note.issue.identifier isEqual:issue.identifier]) {
                    note.issue = issue;
                }
            } else {
                [pending addObject:issueFullIdentifier];
            }
        }
        
        NSArray *markAsRead = [notes filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT issueFullIdentifier IN %@ AND unread = YES", issueIdentifiers]];
        for (LocalNotification *needsRead in markAsRead) {
            needsRead.unread = @NO;
        }
        
        [_moc save:&err];
        if (err) ErrLog(@"%@", err);
        
        dispatch_async(_q, ^{
            [_pendingIssues unionSet:pending];
            
        });
    }];
}

- (NSString *)issueFullIdentifier:(LocalIssue *)li {
    NSParameterAssert(li);
    return [NSString issueIdentifierWithOwner:li.repository.owner.login repo:li.repository.name number:li.number];
}

- (NSArray *)changedIssueIdentifiers:(NSNotification *)note {
    NSMutableSet *changed = [NSMutableSet new];
    
    [note enumerateModifiedObjects:^(id obj, CoreDataModificationType modType, BOOL *stop) {
        if ([obj isKindOfClass:[LocalIssue class]]) {
            id identifier = [self issueFullIdentifier:obj];
            [changed addObject:identifier];
        }
    }];
    
    return changed.count > 0 ? [changed allObjects] : nil;
}

- (void)mocDidChange:(NSNotification *)note {
    //DebugLog(@"%@", note);
    
    // calculate which issues are affected by this change
    NSArray *changedIssueIdentifiers = [self changedIssueIdentifiers:note];
    
    dispatch_async(_q, ^{
        if ([_pendingIssues count]) {
            NSMutableSet *linkThese = [_pendingIssues mutableCopy];
            [linkThese intersectSet:[NSSet setWithArray:changedIssueIdentifiers]];
            
            [self linkNotifications:linkThese];
        }
    });
}

- (void)linkNotifications:(NSSet *)linkThese {
    dispatch_assert_current_queue(_q);
    
    if ([linkThese count] == 0) return;
    
    [_moc performBlock:^{
        NSError *err = nil;
        
        NSFetchRequest *noteFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
        noteFetch.predicate = [NSPredicate predicateWithFormat:@"issueFullIdentifier IN %@", linkThese];
        
        NSFetchRequest *issuesFetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalIssue"];
        issuesFetch.predicate = [_store predicateForIssueIdentifiers:[linkThese allObjects]];
        
        NSArray *notes = [_moc executeFetchRequest:noteFetch error:&err];
        
        if (err) ErrLog(@"%@", err);
        err = nil;
        
        NSArray *issues = [_moc executeFetchRequest:issuesFetch error:&err];
        
        if (err) ErrLog(@"%@", err);
        err = nil;
        
        NSDictionary *issuesLookup = [NSDictionary lookupWithObjects:issues keyPath:@"fullIdentifier"];
        
        for (LocalNotification *note in notes) {
            note.issue = issuesLookup[note.issueFullIdentifier];
        }
        
        [_moc save:&err];
        if (err) ErrLog(@"%@", err);
        
        DebugLog(@"Linked notifications: %@", linkThese);
        
        dispatch_async(_q, ^{
            [_pendingIssues minusSet:linkThese];
        });
    }];
}

- (void)discoverPendingIssues {
    [_moc performBlock:^{
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"issueFullIdentifier != nil AND issue = nil"];
        
        NSArray *pending = [_moc executeFetchRequest:fetch error:NULL];
        NSMutableSet *pendingIdentifiers = [NSMutableSet new];
        for (LocalNotification *note in pending) {
            [pendingIdentifiers addObject:note.issueFullIdentifier];
        }
        
        DebugLog(@"Discovered pending issues: %@", pendingIdentifiers);
        
        dispatch_async(_q, ^{
            self.pendingIssues = pendingIdentifiers;
        });
    }];
}

- (void)discoverLastUpdateAndStartPolling {
    [_moc performBlock:^{
        NSError *err = nil;
        
        NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalNotification"];
        fetch.predicate = [NSPredicate predicateWithFormat:@"updatedAt = max(updatedAt)"];
        fetch.resultType = NSDictionaryResultType;
        fetch.propertiesToFetch = @[@"updatedAt"];
        fetch.fetchLimit = 1;
        
        NSDate *max = [[[_moc executeFetchRequest:fetch error:&err] firstObject] objectForKey:@"updatedAt"];
        if (err) ErrLog(@"%@", err);
        err = nil;

        DebugLog(@"Discovered last update: %@", max);
        
        dispatch_async(_q, ^{
            self.lastUpdate = max;
            [self poll];
        });
    }];
}

@end

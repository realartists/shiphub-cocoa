//
//  PRCreateController.m
//  ShipHub
//
//  Created by James Howard on 3/14/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRCreateController.h"

#import "Error.h"
#import "Extras.h"
#import "CompletingTextField.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Repo.h"
#import "RequestPager.h"
#import "Auth.h"

@interface PRPullDestination : NSObject

@property (nonatomic, copy) NSString *repoFullName;
@property (nonatomic, copy) NSArray *upstreamRepoFullNames;
@property (nonatomic, copy) NSString *defaultBranchName;
@property (nonatomic, copy) NSArray<NSString *> *branchNames;

@end

@interface PRPushEvent : NSObject

+ (PRPushEvent *)eventWithDictionary:(NSDictionary *)d;

@property (nonatomic, readonly) NSString *repoFullName;
@property (nonatomic, readonly) NSString *branchName;
@property (nonatomic, readonly) NSString *tipCommitMessage;
@property (nonatomic, readonly) NSDate *date;

@property (nonatomic, copy) NSArray<PRPullDestination *> *destinations;

@end

@interface PRCreateTableCellView : NSTableCellView

@property IBOutlet NSTextField *repoBranchLabel;
@property IBOutlet NSTextField *dateLabel;
@property IBOutlet NSTextField *latestCommitLabel;

@end

@interface PRCreateController () <NSTableViewDelegate, NSTableViewDataSource>

@property IBOutlet NSTableView *table;
@property IBOutlet NSProgressIndicator *progressIndicator;
@property IBOutlet NSButton *refreshButton;
@property IBOutlet NSTextField *nothingLabel;
@property IBOutlet CompletingTextField *destRepoField;
@property IBOutlet CompletingTextField *destBranchField;
@property IBOutlet NSButton *nextButton;

@property BOOL loading;
@property NSArray<PRPushEvent *> *pushes;

@end

@implementation PRCreateController

- (NSString *)windowNibName { return @"PRCreateController"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _progressIndicator.displayedWhenStopped = NO;
    
    [self loadData];
}

- (void)handleLoadError:(NSError *)error {
    _loading = NO;
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Unable to load git push data", nil);
    alert.informativeText = [error localizedDescription];
    
    [alert addButtonWithTitle:NSLocalizedString(@"Close", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self close];
        } else {
            [self loadData];
        }
    }];
}

- (void)handleEmpty {
    [_progressIndicator stopAnimation:nil];
    _nothingLabel.hidden = NO;
    _nextButton.enabled = NO;
    _refreshButton.hidden = NO;
    _loading = NO;
}

- (void)loadData {
    if (_loading)
        return;
    
    _loading = YES;
    
    [_progressIndicator startAnimation:nil];
    _nextButton.enabled = NO;
    _nothingLabel.hidden = YES;
    _refreshButton.hidden = YES;
    
    _destRepoField.enabled = NO;
    _destBranchField.enabled = NO;
    
    Auth *auth = [[DataStore activeStore] auth];
    RequestPager *pager = [[RequestPager alloc] initWithAuth:auth];
    NSString *endpoint = [NSString stringWithFormat:@"/users/%@/events", auth.account.login];
    
    // Get just the first page of events, that should be enough
    [pager jsonTask:[pager get:endpoint] completion:^(id json, NSHTTPURLResponse *response, NSError *err) {
        if (![json isKindOfClass:[NSArray class]] && !err) {
            err = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        RunOnMain(^{
            if (!err) {
                [self continueLoadWithEvents:[json filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"type == 'PushEvent'"]]];
            } else {
                [self handleLoadError:err];
            }
        });
    }];
}

- (void)continueLoadWithEvents:(NSArray *)eventDicts {
    NSArray *evs = [eventDicts arrayByMappingObjects:^id(id obj) {
        return [PRPushEvent eventWithDictionary:obj];
    }];
    // only care about pushes in the past week
    evs = [evs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"date > FUNCTION(now(), '_ship_dateByAddingDays:', -7)"]];
    NSArray *uniqueRepos = [[NSSet setWithArray:[evs arrayByMappingObjects:^id(id obj) {
        return [obj repoFullName];
    }]] allObjects];
    
    if (evs.count == 0) {
        [self handleEmpty];
        return;
    }
    
    // get full information on all of these repos
    Auth *auth = [[DataStore activeStore] auth];
    RequestPager *pager = [[RequestPager alloc] initWithAuth:auth];
    
    NSArray *repoRequests = [uniqueRepos arrayByMappingObjects:^id(id obj) {
        NSString *endpoint = [NSString stringWithFormat:@"/repos/%@", obj];
        return [pager get:endpoint];
    }];
    
    [pager jsonTasks:repoRequests completion:^(NSArray *json, NSError *err) {
        RunOnMain(^{
            if (err) {
                [self handleLoadError:err];
            } else {
                [self continueWithEvents:evs andRepoInfos:json];
            }
        });
    }];
}

- (void)continueWithEvents:(NSArray *)events andRepoInfos:(NSArray *)infos {
    NSMutableArray *allRepoInfos = [infos mutableCopy];
    
    Auth *auth = [[DataStore activeStore] auth];
    RequestPager *pager = [[RequestPager alloc] initWithAuth:auth];
    
    for (NSDictionary *repoInfo in infos) {
        if (repoInfo[@"parent"]) {
            [allRepoInfos addObject:repoInfo[@"parent"]];
        }
        if (repoInfo[@"source"]) {
            [allRepoInfos addObject:repoInfo[@"source"]];
        }
    }
    
    NSArray *branchRequests = [allRepoInfos arrayByMappingObjects:^id(NSDictionary *obj) {
        NSString *endpoint = [NSString stringWithFormat:@"/repos/%@/branches", obj[@"full_name"]];
        return [pager get:endpoint];
    }];
    
    [pager jsonTasks:branchRequests completion:^(NSArray *json, NSError *err) {
        RunOnMain(^{
            if (err) {
                [self handleLoadError:err];
            } else {
                [self continueWithEvents:events repoInfos:allRepoInfos branches:json];
            }
        });
    }];
}

- (void)continueWithEvents:(NSArray *)events repoInfos:(NSArray *)repoInfos branches:(NSArray *)branches {
    NSAssert(repoInfos.count == branches.count, nil);
    
    NSMutableArray *destinations = [NSMutableArray arrayWithCapacity:repoInfos.count];
    for (NSUInteger i = 0; i < repoInfos.count && i < branches.count; i++) {
        PRPullDestination *dest = [PRPullDestination new];
        NSDictionary *repoInfo = repoInfos[i];
        dest.repoFullName = repoInfo[@"full_name"];
        NSMutableArray *upstreams = [NSMutableArray new];
        if (repoInfo[@"parent"]) {
            [upstreams addObject:repoInfo[@"parent"][@"full_name"]];
        }
        if (repoInfo[@"source"]) {
            NSString *name = repoInfo[@"source"][@"full_name"];
            if (![upstreams containsObject:name]) {
                [upstreams addObject:name];
            }
        }
        dest.upstreamRepoFullNames = upstreams;
        dest.defaultBranchName = repoInfo[@"default_branch"];
        dest.branchNames = [branches[i] arrayByMappingObjects:^id(NSDictionary *obj) {
            return obj[@"name"];
        }];
        [destinations addObject:dest];
    }
    
    NSDictionary *destLookup = [NSDictionary lookupWithObjects:destinations keyPath:@"repoFullName"];
    
    // ignore pushes to default branches of non-forked repos
    events = [events filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PRPushEvent *ev, NSDictionary<NSString *,id> * _Nullable bindings) {
        
        PRPullDestination *dest = destLookup[ev.repoFullName];
        NSAssert(dest != nil, nil);
        
        BOOL hasADestination = dest.upstreamRepoFullNames.count || ![[dest defaultBranchName] isEqualToString:ev.branchName];
        return hasADestination;
    }]];
    
    if (events.count == 0) {
        [self handleEmpty];
    }
    
    for (PRPushEvent *ev in events) {
        PRPullDestination *d1 = destLookup[ev.repoFullName];
        
        if ([d1.defaultBranchName isEqualToString:ev.branchName]) {
            ev.destinations = [d1.upstreamRepoFullNames arrayByMappingObjects:^id(PRPullDestination *obj) {
                return destLookup[obj.repoFullName];
            }];
        } else if (d1.upstreamRepoFullNames.count > 0) {
            ev.destinations = [@[d1] arrayByAddingObjectsFromArray:[d1.upstreamRepoFullNames arrayByMappingObjects:^id(PRPullDestination *obj) {
                return destLookup[obj.repoFullName];
            }]];
        } else {
            ev.destinations = @[d1];
        }
    }
    
    [self continueWithFullEvents:events];
}

- (void)continueWithFullEvents:(NSArray *)events {
    [_progressIndicator stopAnimation:nil];
    _loading = NO;
    _refreshButton.hidden = NO;
    _pushes = events;
    [_table reloadData];
    if (_pushes.count) {
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
}

- (IBAction)showPushHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.realartists.com/docs/2.0/pullrequests.html"]];
}

- (IBAction)showPushInfo:(id)sender {
    
}

- (IBAction)cancel:(id)sender {
    [self close];
    CFRelease((__bridge CFTypeRef)self); // break retain cycle
}

- (IBAction)next:(id)sender {
    // TODO: [[IssueDocumentController sharedDocumentController] newIssueWithTemplate:prTemplate];
    
    [self close];
    CFRelease((__bridge CFTypeRef)self); // break retain cycle
}

- (IBAction)refresh:(id)sender {
    [self loadData];
}

- (void)showWindow:(id)sender {
    [super showWindow:sender];
    CFRetain((__bridge CFTypeRef)self); // create retain cycle until we're closed or canceled
}

#pragma mark NSTableViewDelegate

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    PRCreateTableCellView *cell = [tableView makeViewWithIdentifier:@"PushItem" owner:self];
    
    PRPushEvent *ev = _pushes[row];
    NSMutableAttributedString *repoBranchStr = [NSMutableAttributedString new];
    
    [repoBranchStr appendAttributes:@{ NSFontAttributeName : [NSFont systemFontOfSize:13.0] } format:@"%@ ", ev.repoFullName];
    [repoBranchStr appendAttributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:13.0] } format:@"%@", ev.branchName];
    
    cell.repoBranchLabel.attributedStringValue = repoBranchStr;
    cell.dateLabel.stringValue = [ev.date shortUserInterfaceString];
    
    cell.latestCommitLabel.stringValue = ev.tipCommitMessage ?: @"";
    
    return cell;
}

#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _pushes.count;
}

@end

@implementation PRCreateTableCellView

@end

@implementation PRPushEvent

+ (PRPushEvent *)eventWithDictionary:(NSDictionary *)d {
    PRPushEvent *ev = [PRPushEvent new];
    ev->_repoFullName = d[@"repo"][@"name"];
    ev->_branchName = [d[@"payload"][@"ref"] substringFromIndex:[@"refs/heads/" length]];
    NSDictionary *tipCommit = [d[@"payload"][@"commits"] firstObject];
    ev->_tipCommitMessage = tipCommit[@"message"];
    ev->_date = [NSDate dateWithJSONString:d[@"created_at"]];
    
    return ev;
}

@end

@implementation PRPullDestination

@end

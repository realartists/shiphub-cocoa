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
#import "DataStore.h"
#import "MetadataStore.h"
#import "Repo.h"
#import "RequestPager.h"
#import "Auth.h"
#import "Issue.h"
#import "IssueDocumentController.h"
#import "Repo.h"

@interface PRPullDestination : NSObject

@property (nonatomic, copy) NSNumber *repoID;
@property (nonatomic, copy) NSString *repoFullName;
@property (nonatomic, copy) NSArray *upstreamRepoFullNames;
@property (nonatomic, copy) NSString *defaultBranchName;
@property (nonatomic, copy) NSArray<NSString *> *branchNames;

@end

typedef NS_ENUM(NSInteger, PRPushEventType) {
    PRPushEventTypePush,
    PRPushEventTypeCreateBranch
};

@interface PRPushEvent : NSObject

+ (PRPushEvent *)eventWithDictionary:(NSDictionary *)d;

@property (nonatomic, copy) NSString *repoFullName;
@property (nonatomic, copy) NSString *branchName;
@property (nonatomic, copy) NSString *tipCommitMessage;
@property (nonatomic, strong) NSDate *date;

@property (nonatomic, readonly) PRPushEventType type;

@property (nonatomic, copy) NSArray<PRPullDestination *> *destinations;

@end

@interface PRCreateTableCellView : NSTableCellView

@property IBOutlet NSTextField *repoBranchLabel;
@property IBOutlet NSTextField *dateLabel;
@property IBOutlet NSTextField *latestCommitLabel;
@property IBOutlet NSButton *linkButton;

@end

@interface PRCreateController () <NSTableViewDelegate, NSTableViewDataSource>

@property IBOutlet NSTableView *table;
@property IBOutlet NSProgressIndicator *progressIndicator;
@property IBOutlet NSButton *refreshButton;
@property IBOutlet NSTextField *nothingLabel;
@property IBOutlet NSComboBox *destRepoField;
@property IBOutlet NSComboBox *destBranchField;
@property IBOutlet NSButton *nextButton;

@property BOOL loading;
@property NSArray<PRPushEvent *> *pushes;

@property PRPushEvent *selectedPush;

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
    [_progressIndicator stopAnimation:nil];
    
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
    
    _destRepoField.stringValue = @"";
    _destBranchField.stringValue = @"";
    _destRepoField.enabled = NO;
    _destBranchField.enabled = NO;
    
    RequestPager *pager = [self pager];
    Auth *auth = [[DataStore activeStore] auth];
    NSString *endpoint = [NSString stringWithFormat:@"/users/%@/events", auth.account.login];
    
    // Get just the first page of events, that should be enough
    [pager jsonTask:[pager get:endpoint] completion:^(id json, NSHTTPURLResponse *response, NSError *err) {
        if (![json isKindOfClass:[NSArray class]] && !err) {
            err = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        RunOnMain(^{
            if (!err) {
                [self continueLoadWithEvents:[json filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"type == 'PushEvent' || (type == 'CreateEvent' AND payload.ref_type == 'branch')"]]];
            } else {
                [self handleLoadError:err];
            }
        });
    }];
}

- (RequestPager *)pager {
    Auth *auth = [[DataStore activeStore] auth];
    RequestPager *pager = [[RequestPager alloc] initWithAuth:auth];
    return pager;
}

- (void)continueLoadWithEvents:(NSArray *)eventDicts {
    NSArray *evs = [eventDicts arrayByMappingObjects:^id(id obj) {
        return [PRPushEvent eventWithDictionary:obj];
    }];
    // only care about pushes in the past week
    evs = [evs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"date > FUNCTION(now(), '_ship_dateByAddingDays:', -7)"]];
    
    if (evs.count == 0) {
        [self handleEmpty];
        return;
    }
    
    // take only the latest events for a given repoFullName/branchName pair
    NSMutableSet *seen = [NSMutableSet new];
    NSMutableArray *uniqueEvs = [NSMutableArray new];
    for (PRPushEvent *ev in evs) {
        NSString *pair = [NSString stringWithFormat:@"%@:%@", ev.repoFullName, ev.branchName];
        if (![seen containsObject:pair]) {
            [seen addObject:pair];
            [uniqueEvs addObject:ev];
        }
    }
    evs = uniqueEvs;
    
    NSArray *needTips = [evs filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"type == %ld", PRPushEventTypeCreateBranch]];
    if (needTips.count > 0) {
        RequestPager *pager = [self pager];
        NSArray *refRequests = [needTips arrayByMappingObjects:^id(PRPushEvent *obj) {
            NSString *endpoint = [NSString stringWithFormat:@"repos/%@/git/refs/heads/%@", obj.repoFullName, obj.branchName];
            return [pager get:endpoint];
        }];
        
        [pager tasks:refRequests completion:^(NSArray<URLSessionResult *> *results) {
            
            NSMutableIndexSet *failedIdxes = [NSMutableIndexSet new];
            NSUInteger c = results.count;
            NSMutableArray *json = [NSMutableArray new];
            
            for (NSUInteger i = 0; i < c; i++) {
                URLSessionResult *r = results[i];
                if (r.error) {
                    // network error
                    RunOnMain(^{
                        [self handleLoadError:r.error];
                    });
                    return;
                } else if (((NSHTTPURLResponse *)r.response).statusCode >= 400) {
                    // missing ref error
                    [failedIdxes addIndex:i];
                } else {
                    [json addObject:r.json];
                }
            }
            
            NSArray *filteredEvs = evs;
            NSArray *filteredNeedTips = needTips;
            
            if ([failedIdxes count]) {
                NSMutableArray *mutableNeedTips = [needTips mutableCopy];
                NSArray *failedEvs = [mutableNeedTips objectsAtIndexes:failedIdxes];
                [mutableNeedTips removeObjectsAtIndexes:failedIdxes];
                NSMutableArray *mutableEvs = [evs mutableCopy];
                [mutableEvs removeObjectsInArray:failedEvs];
                
                filteredNeedTips = mutableNeedTips;
                filteredEvs = mutableEvs;
            }
            
            NSArray *commitRequests = [json arrayByMappingObjects:^id(NSDictionary *obj) {
                return [pager get:obj[@"object"][@"url"]];
            }];
            
            [pager jsonTasks:commitRequests completion:^(NSArray *commits, NSError *err2) {
                
                if (err2) {
                    RunOnMain(^{
                        [self handleLoadError:err2];
                    });
                    return;
                }
                
                NSUInteger i = 0;
                for (PRPushEvent *pr in filteredNeedTips) {
                    NSDictionary *commit = commits[i];
                    pr.tipCommitMessage = commit[@"message"];
                    i++;
                }
                
                RunOnMain(^{
                    [self continueFetchingRepoInfoForEvents:filteredEvs];
                });
            }];
            
        }];
        
    } else {
        [self continueFetchingRepoInfoForEvents:evs];
    }
}

- (void)continueFetchingRepoInfoForEvents:(NSArray *)events {
    // get full information on all of these repos
    RequestPager *pager = [self pager];
    
    NSArray *uniqueRepos = [[NSSet setWithArray:[events arrayByMappingObjects:^id(id obj) {
        return [obj repoFullName];
    }]] allObjects];
    
    NSArray *repoRequests = [uniqueRepos arrayByMappingObjects:^id(id obj) {
        NSString *endpoint = [NSString stringWithFormat:@"/repos/%@", obj];
        return [pager get:endpoint];
    }];
    
    [pager jsonTasks:repoRequests completion:^(NSArray *json, NSError *err) {
        RunOnMain(^{
            if (err) {
                [self handleLoadError:err];
            } else {
                [self continueWithEvents:events andRepoInfos:json];
            }
        });
    }];
}

- (void)continueWithEvents:(NSArray *)events andRepoInfos:(NSArray *)infos {
    NSMutableArray *allRepoInfos = [infos mutableCopy];
    
    RequestPager *pager = [self pager];
    
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
        NSDictionary *repoInfo = repoInfos[i];
        NSString *repoFullName = repoInfo[@"full_name"];
        PRPullDestination *dest = [PRPullDestination new];
        dest.repoFullName = repoFullName;
        dest.repoID = repoInfo[@"id"];
        NSMutableArray *upstreams = [NSMutableArray new];
        if (repoInfo[@"source"]) {
            NSString *name = repoInfo[@"source"][@"full_name"];
            [upstreams addObject:name];
        }
        if (repoInfo[@"parent"]) {
            NSString *name = repoInfo[@"parent"][@"full_name"];
            if (![upstreams containsObject:name]) {
                [upstreams addObject:name];
            }
        }
        
        dest.upstreamRepoFullNames = upstreams;
        dest.defaultBranchName = repoInfo[@"default_branch"];
        dest.branchNames = [branches[i] arrayByMappingObjects:^id(NSDictionary *obj) {
            return obj[@"name"];
        }];
        if (![dest.branchNames containsObject:dest.defaultBranchName]) {
            dest.branchNames = [dest.branchNames arrayByAddingObject:dest.defaultBranchName];
        }
        
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
    
    MetadataStore *ms = [[DataStore activeStore] metadataStore];
    
    for (PRPushEvent *ev in events) {
        PRPullDestination *d1 = destLookup[ev.repoFullName];
        
        if ([d1.defaultBranchName isEqualToString:ev.branchName]) {
            ev.destinations = [d1.upstreamRepoFullNames arrayByMappingObjects:^id(PRPullDestination *obj) {
                return destLookup[obj.repoFullName];
            }];
        } else if (d1.upstreamRepoFullNames.count > 0) {
            ev.destinations = [[d1.upstreamRepoFullNames arrayByMappingObjects:^id(PRPullDestination *obj) {
                return destLookup[obj.repoFullName];
            }] arrayByAddingObject:d1];
        } else {
            ev.destinations = @[d1];
        }
        
        // only keep destinations where we can create and modify PRs
        ev.destinations = [ev.destinations filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PRPullDestination *dest, NSDictionary<NSString *,id> * _Nullable bindings) {
            return [ms repoWithFullName:dest.repoFullName] != nil;
        }]];
    }
    
    NSMutableSet *uniqueDestinationRepoIDs = [NSMutableSet new];
    for (PRPushEvent *ev in events) {
        for (PRPullDestination *dest in ev.destinations) {
            [uniqueDestinationRepoIDs addObject:dest.repoID];
        }
    }
    
    // filter events that already have an open issue
    NSPredicate *issuesPredicate = [NSPredicate predicateWithFormat:@"state = 'open' AND pullRequest = YES AND repository.identifier IN %@", uniqueDestinationRepoIDs];
    [[DataStore activeStore] issuesMatchingPredicate:issuesPredicate completion:^(NSArray<Issue *> *issues, NSError *error) {
        
        if (error) {
            [self handleLoadError:error];
        } else {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                static NSString *const pairFormat = @"%@:%@<%@:%@";
                
                NSMutableSet *existingPRs = [NSMutableSet new];
                for (Issue *i in issues) {
                    // destRepoFullName:destBranch<srcRepoFullName:srcBranch
                    NSString *pair = [NSString stringWithFormat:pairFormat,
                                      i.base[@"repo"][@"fullName"], i.base[@"ref"],
                                      i.head[@"repo"][@"fullName"], i.head[@"ref"]];
                    [existingPRs addObject:pair];
                };
                
                for (PRPushEvent *ev in events) {
                    // filter out any destinations where the default branch already has a pull request to it
                    ev.destinations = [ev.destinations filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PRPullDestination *dest, NSDictionary<NSString *,id> * _Nullable bindings) {
                        
                        NSString *pair = [NSString stringWithFormat:pairFormat,
                                          dest.repoFullName, dest.defaultBranchName,
                                          ev.repoFullName, ev.branchName];
                        
                        return ![existingPRs containsObject:pair];
                    }]];
                }
                
                // filter events with empty destinations
                NSArray *filteredEvents = [events filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"destinations.@count > 0"]];
                
                RunOnMain(^{
                    [self continueWithFullEvents:filteredEvents];
                });
                
            });
        }
        
    }];
}

- (void)continueWithFullEvents:(NSArray *)events {
    if (events.count == 0) {
        [self handleEmpty];
        return;
    }
    
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
    NSInteger row = [[sender extras_representedObject] integerValue];
    if (row >= 0 && row < _pushes.count) {
        PRPushEvent *ev = _pushes[row];
        NSString *webHost = [[[[[DataStore activeStore] auth] account] ghHost] stringByReplacingOccurrencesOfString:@"api." withString:@""];
        NSString *URLStr = [NSString stringWithFormat:@"https://%@/%@/tree/%@", webHost, ev.repoFullName, ev.branchName];
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:URLStr]];
    }
}

- (IBAction)cancel:(id)sender {
    [self close];
    CFRelease((__bridge CFTypeRef)self); // break retain cycle
}

- (IBAction)next:(id)sender {
    MetadataStore *ms = [[DataStore activeStore] metadataStore];
    
    if (!_selectedPush) {
        return;
    }
    
    NSString *destRepoFullName = _destRepoField.stringValue;
    NSString *destBranchName = _destBranchField.stringValue;
    
    Repo *r = [ms repoWithFullName:destRepoFullName];
    
    NSString *tipCommit = _selectedPush.tipCommitMessage;
    NSArray *commitLines = [tipCommit componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSString *title = [commitLines firstObject];
    NSString *body = nil;
    if ([commitLines count] > 1) {
        body = [[tipCommit substringFromIndex:[title length]] trim];
    }
    
    NSDictionary *base = @{ @"repo" : @{ @"full_name" : destRepoFullName },
                            @"ref" : destBranchName };
    NSDictionary *head = @{ @"repo" : @{ @"full_name" : _selectedPush.repoFullName },
                            @"ref" : _selectedPush.branchName };
    
    Issue *prTemplate = [[Issue alloc] initPRWithTitle:title repo:r body:body baseInfo:base headInfo:head];
    
    [[IssueDocumentController sharedDocumentController] newDocumentWithIssueTemplate:prTemplate];
    
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

- (PRPullDestination *)selectedDestination {
    NSString *destRepo = _destRepoField.stringValue;
    PRPullDestination *dest = [_selectedPush.destinations firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"repoFullName == %@", destRepo]] ?: [_selectedPush.destinations firstObject];
    return dest;
}

- (IBAction)destRepoChanged:(id)sender {
    PRPullDestination *dest = [self selectedDestination];
    _destBranchField.stringValue = dest.defaultBranchName ?: @"";
    if (_destRepoField.indexOfSelectedItem == -1) {
        _destRepoField.stringValue = dest.repoFullName;
    }
}

- (IBAction)destBranchChanged:(id)sender {
    PRPullDestination *dest = [self selectedDestination];
    if (_destBranchField.indexOfSelectedItem == -1) {
        _destBranchField.stringValue = dest.defaultBranchName;
    }
}

#pragma mark NSTableViewDelegate

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    PRCreateTableCellView *cell = [tableView makeViewWithIdentifier:@"PushItem" owner:self];
    
    PRPushEvent *ev = _pushes[row];
    NSMutableAttributedString *repoBranchStr = [NSMutableAttributedString new];
    
    [repoBranchStr appendAttributes:@{ NSFontAttributeName : [NSFont systemFontOfSize:13.0] } format:@"%@ ", ev.repoFullName];
    [repoBranchStr appendAttributes:@{ NSFontAttributeName: [NSFont boldSystemFontOfSize:13.0] } format:@"%@", ev.branchName];
    
    cell.repoBranchLabel.attributedStringValue = repoBranchStr;
    cell.dateLabel.stringValue = [ev.date shortUserInterfaceString];
    
    cell.latestCommitLabel.stringValue = ev.tipCommitMessage ?: @"";
    
    cell.linkButton.extras_representedObject = @(row);
    
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = [_table selectedRow];
    if (row >= 0 && row < _pushes.count) {
        _selectedPush = _pushes[row];
        
        PRPullDestination *topDest = [_selectedPush.destinations firstObject];
        _destRepoField.stringValue = topDest.repoFullName;
        _destBranchField.stringValue = topDest.defaultBranchName;
        _destRepoField.enabled = YES;
        _destBranchField.enabled = YES;
        _nextButton.enabled = YES;
    } else {
        _selectedPush = nil;
        _destRepoField.stringValue = @"";
        _destRepoField.enabled = NO;
        _destBranchField.stringValue = @"";
        _destBranchField.enabled = NO;
        _nextButton.enabled = NO;
    }
}

#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _pushes.count;
}

#pragma mark NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)comboBox {
    if (comboBox == _destRepoField) {
        return _selectedPush.destinations.count;
    } else if (comboBox == _destBranchField) {
        PRPullDestination *dest = [self selectedDestination];
        return dest.branchNames.count;
    }
    return 0;
}

- (nullable id)comboBox:(NSComboBox *)comboBox objectValueForItemAtIndex:(NSInteger)index {
    if (comboBox == _destRepoField) {
        return [_selectedPush.destinations[index] repoFullName];
    } else if (comboBox == _destBranchField) {
        PRPullDestination *dest = [self selectedDestination];
        return dest.branchNames[index];
    }
    return nil;
}

- (NSUInteger)comboBox:(NSComboBox *)comboBox indexOfItemWithStringValue:(NSString *)string {
    if (comboBox == _destRepoField) {
        return [_selectedPush.destinations indexOfObjectPassingTest:^BOOL(PRPullDestination * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [[obj repoFullName] isEqualToString:string];
        }];
    } else if (comboBox == _destBranchField) {
        PRPullDestination *dest = [self selectedDestination];
        return [dest.branchNames indexOfObject:string];
    }
    return NSNotFound;
}

- (nullable NSString *)comboBox:(NSComboBox *)comboBox completedString:(NSString *)string {
    if (comboBox == _destRepoField) {
        return [[_selectedPush valueForKeyPath:@"destinations.repoFullName"] firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", string]];
    } else if (comboBox == _destBranchField) {
        PRPullDestination *dest = [self selectedDestination];
        return [dest.branchNames firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"SELF beginswith[cd] %@", string]];
    }
    return nil;
}

@end

@implementation PRCreateTableCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    
    if (backgroundStyle == NSBackgroundStyleLight) {
        NSMutableAttributedString *str = [_repoBranchLabel.attributedStringValue mutableCopy];
        [str addAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] range:NSMakeRange(0, str.length)];
        _repoBranchLabel.attributedStringValue = str;
        
        _dateLabel.textColor = [NSColor secondaryLabelColor];
        _latestCommitLabel.textColor = [NSColor blackColor];
    } else {
        NSMutableAttributedString *str = [_repoBranchLabel.attributedStringValue mutableCopy];
        [str addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, str.length)];
        _repoBranchLabel.attributedStringValue = str;
        
        _dateLabel.textColor = [NSColor whiteColor];
        _latestCommitLabel.textColor = [NSColor whiteColor];
    }
}

@end

@implementation PRPushEvent

+ (PRPushEvent *)eventWithDictionary:(NSDictionary *)d {
    PRPushEvent *ev = [PRPushEvent new];
    ev->_repoFullName = d[@"repo"][@"name"];
    ev->_date = [NSDate dateWithJSONString:d[@"created_at"]];
    if ([d[@"type"] isEqualToString:@"PushEvent"]) {
        ev->_type = PRPushEventTypePush;
        ev->_branchName = [d[@"payload"][@"ref"] substringFromIndex:[@"refs/heads/" length]];
        NSDictionary *tipCommit = [d[@"payload"][@"commits"] firstObject];
        ev->_tipCommitMessage = tipCommit[@"message"];
    } else if ([d[@"type"] isEqualToString:@"CreateEvent"]) {
        ev->_branchName = d[@"payload"][@"ref"];
        ev->_type = PRPushEventTypeCreateBranch;
    }
    
    return ev;
}

@end

@implementation PRPullDestination

@end

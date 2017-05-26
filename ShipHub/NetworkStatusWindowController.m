//
//  NetworkStatusWindowController.m
//  ShipHub
//
//  Created by James Howard on 5/26/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "NetworkStatusWindowController.h"

#import "DataStore.h"
#import "Extras.h"
#import "Reachability.h"

@interface NetworkStatusWindowController () {
    BOOL _upToDate;
}

@property IBOutlet NSProgressIndicator *progress;
@property IBOutlet NSTextField *subtitle;
@property IBOutlet NSTextField *noteField;

@end

@implementation NetworkStatusWindowController

- (NSString *)windowNibName { return @"NetworkStatusWindowController"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreActiveDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreWillBeginNetworkActivityNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreDidEndNetworkActivityNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:ReachabilityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreDidUpdateProgressNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreRateLimitedDidChangeNotification object:nil];
    
    [self update:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)update:(NSNotification *)note {
    BOOL online = [[Reachability sharedInstance] isReachable];
    BOOL reachabilityInited = [[Reachability sharedInstance] receivedFirstUpdate];
    
    BOOL offline = !online && reachabilityInited;
    DataStore *store = [DataStore activeStore];
    NSDate *lastUpdated = [store lastUpdated];
    NSDate *rateLimited = [store rateLimitedUntil];
    NSString *since = [lastUpdated shortUserInterfaceString];
    BOOL connected = [store isSyncConnectionActive];
    double logProgress = [store logSyncProgress];
    double spiderProgress = [store spiderProgress];
    
    _upToDate = NO;
    
    if (offline) {
        if (since) {
            _subtitle.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Offline. Last Updated %@", nil), since];
        } else {
            _subtitle.stringValue = NSLocalizedString(@"Offline", nil);
        }
        _progress.indeterminate = YES;
        [_progress stopAnimation:nil];
    } else if (rateLimited) {
        _subtitle.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Rate Limited Until %@", nil), [rateLimited shortUserInterfaceString]];
        _progress.indeterminate = YES;
        [_progress stopAnimation:nil];
    } else if (!connected) {
        _subtitle.stringValue = NSLocalizedString(@"Connecting ...", nil);
        _progress.indeterminate = YES;
        [_progress startAnimation:nil];
    } else if (spiderProgress < 0.0) {
        _subtitle.stringValue = NSLocalizedString(@"Fetching repository list", nil);
        _progress.indeterminate = YES;
        [_progress startAnimation:nil];
    } else if (spiderProgress < 1.0) {
        _subtitle.stringValue = NSLocalizedString(@"Fetching issues", nil);
        _progress.indeterminate = NO;
        _progress.doubleValue = spiderProgress;
        [_progress startAnimation:nil];
    } else if (logProgress < 0.0) {
        _subtitle.stringValue = NSLocalizedString(@"Connecting ...", nil);
        _progress.indeterminate = YES;
        [_progress startAnimation:nil];
    } else if (logProgress < 1.0) {
        _subtitle.stringValue = NSLocalizedString(@"Receiving sync log", nil);
        _progress.indeterminate = NO;
        _progress.doubleValue = logProgress;
        [_progress startAnimation:nil];
    } else {
        _subtitle.stringValue = NSLocalizedString(@"Up to date", nil);
        _progress.doubleValue = 1.0;
        _upToDate = YES;
        [_progress stopAnimation:nil];
        [self dismissController:nil];
    }
}

- (BOOL)beginSheetInWindowIfNeeded:(NSWindow *)window {
    if (self.window.sheetParent) return NO;
    
    [self window];
    [self update:nil];
    
    if (!_upToDate) {
        [window beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
            [_progress stopAnimation:nil];
        }];
        return YES;
    } else {
        return NO;
    }
}

- (IBAction)dismissController:(id)sender {
    [self.window.sheetParent endSheet:self.window];
}

@end

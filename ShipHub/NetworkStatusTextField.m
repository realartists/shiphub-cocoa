//
//  NetworkStatusTextField.m
//  Ship
//
//  Created by James Howard on 12/16/15.
//  Copyright © 2015 Real Artists, Inc. All rights reserved.
//

#import "NetworkStatusTextField.h"

#import "DataStore.h"
#import "Extras.h"
#import "Reachability.h"

@implementation NetworkStatusTextField {
    BOOL _commonInited;
}

- (id)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    if (!_commonInited) {
        _commonInited = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreActiveDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreWillBeginNetworkActivityNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreDidEndNetworkActivityNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:ReachabilityDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreDidUpdateProgressNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update:) name:DataStoreRateLimitedDidChangeNotification object:nil];
        
        [self update:nil];
    }
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
    
    if (offline) {
        if (since) {
            self.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Last Updated %@", nil), since];
        } else {
            self.stringValue = NSLocalizedString(@"Offline", nil);
        }
    } else if (rateLimited) {
        self.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Limited Until %@", nil), [rateLimited shortUserInterfaceString]];
    } else if (!connected) {
        if (since) {
            self.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Last Updated %@", nil), since];
        } else {
            self.stringValue = NSLocalizedString(@"Connecting ...", nil);
        }
    } else if (spiderProgress < 0.0) {
        self.stringValue = NSLocalizedString(@"Fetching Repo List", nil);
    } else if (spiderProgress < 1.0) {
        self.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Loading %.0f%% ...", nil), (spiderProgress * 100.0)];
    } else if (logProgress < 0.0) {
        self.stringValue = NSLocalizedString(@"Connecting ...", nil);
    } else if (logProgress < 1.0) {
        self.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Syncing %.0f%% ...", nil), (logProgress * 100.0)];
    } else {
        self.stringValue = @"";
    }
    
    DebugLog(@"lastUpdated: %@ logProgress: %.0f%% spiderProgress: %.0f%% stringValue:%@", lastUpdated, logProgress * 100.0, spiderProgress * 100.0, self.stringValue);
}

- (void)mouseUp:(NSEvent *)event {
    [super mouseUp:event];
    [self sendAction:self.action to:self.target];
}
@end

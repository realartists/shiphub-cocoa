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
        
        [self update:nil];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)update:(NSNotification *)note {
    BOOL online, reachabilityInited;
    
    // FIXME: Hook this stuff back up
    BOOL offline = !online && reachabilityInited;
    NSDate *lastUpdated = nil; //[[DataStore activeStore] lastUpdated];
    NSString *since = [lastUpdated shortUserInterfaceString];
    double progress = 0.0; // [[DataStore activeStore] problemSyncProgress];
    
    DebugLog(@"lastUpdated: %@ progress: %.0f%%", lastUpdated, progress * 100.0);
    
    
    if (offline) {
        if (since) {
            self.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Last Updated %@", nil), since];
        } else {
            self.stringValue = NSLocalizedString(@"Offline", nil);
        }
    } else if (progress == 0.0) {
        if (since) {
            self.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Last Updated %@", nil), since];
        } else {
            self.stringValue = NSLocalizedString(@"Connecting ...", nil);
        }
    } else if (progress < 1.0) {
        self.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Syncing %.0f%% ...", nil), (progress * 100.0)];
    } else {
        self.stringValue = @"";
    }
}

@end

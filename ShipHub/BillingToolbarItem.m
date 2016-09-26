//
//  BillingToolbarItem.m
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "BillingToolbarItem.h"

#import "DataStore.h"
#import "Billing.h"
#import "Extras.h"
#import "TimeRemainingFormatter.h"

@interface BillingToolbarItem ()

@property (strong) NSSegmentedControl *segmented;
@property (strong) NSTimer *updateTimer;

@end

@implementation BillingToolbarItem

- (void)configureView {
    self.visibilityPriority = NSToolbarItemVisibilityPriorityLow;
    
    CGSize size = CGSizeMake(220, 23);
    _segmented  = [[NSSegmentedControl alloc] initWithFrame:(CGRect){ .origin = CGPointZero, .size = size }];
    _segmented.segmentCount = 1;
    [_segmented setWidth:size.width forSegment:0];
    [_segmented.cell setTrackingMode:NSSegmentSwitchTrackingMomentary];
    
    CGSize overallSize = size;
    overallSize.width += 8.0;
    overallSize.height += 4.0;
    self.minSize = overallSize;
    self.maxSize = overallSize;
    self.view = _segmented;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateState) name:DataStoreBillingStateDidChangeNotification object:nil];
    [self updateState];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_updateTimer invalidate];
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    _segmented.hidden = !enabled;
}

- (void)updateState {
    static TimeRemainingFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [TimeRemainingFormatter new];
    });
    
    [_updateTimer invalidate];
    _updateTimer = nil;
    
    NSString *label = nil;
    
    NSTimeInterval updateInterval = -1.0;
    
    Billing *billing = [[DataStore activeStore] billing];
    if (billing.state == BillingStatePaid) {
        self.enabled = NO;
    } else {
        if (billing.state == BillingStateTrial) {
            NSDate *end = billing.trialEndDate;
            
            updateInterval = [formatter timerUpdateIntervalFromDate:end];
            NSString *remaining = [formatter stringFromDate:end];
            
            label = [NSString stringWithFormat:NSLocalizedString(@"Free Trial: %@", nil), remaining];
        } else {
            label = NSLocalizedString(@"Free Trial: Expired", nil);
        }
        
        if (updateInterval > 0.0) {
            _updateTimer = [NSTimer scheduledTimerWithTimeInterval:updateInterval weakTarget:self selector:@selector(updateState) userInfo:nil repeats:NO];
            DebugLog(@"Will update billing state label at %@", _updateTimer.fireDate);
            _updateTimer.tolerance = updateInterval * 0.1;
        }
        
        [_segmented setLabel:label forSegment:0];
        self.enabled = YES;
    }
}

@end

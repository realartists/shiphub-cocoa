//
//  Billing.m
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Billing.h"

#import "Auth.h"
#import "DataStoreInternal.h"
#import "LocalBilling.h"
#import "Extras.h"

#import <notify.h>

#define TEST_BILLING_STATE 0

NSString *const BillingSubscriptionRefreshHashDidChangeNotification = @"BillingSubscriptionRefreshHashDidChange";

@interface Billing () {
    BillingState _state;
}

@property NSTimer *expirationTimer;
@property int notifyToken;
@property NSString *subscriptionRefreshHash;

@end

@implementation Billing

- (id)initWithDataStore:(DataStore *)store {
    if (self = [super init]) {
        self.store = store;
        [_store performWriteAndWait:^(NSManagedObjectContext *moc) {
            LocalBilling *billing = [self localBilling:moc];
            
            _state = [billing.billingState integerValue];
            _trialEndDate = billing.endDate;
            
            DebugLog(@"Billing state %td trialEndDate %@", _state, _trialEndDate);
            
            [self checkForBillingExpiration];
        }];
        
#if TEST_BILLING_STATE
        __weak __typeof(self) weakSelf = self;
        notify_register_dispatch("com.realartists.Ship.BillingTest", &_notifyToken, dispatch_get_main_queue(), ^(int x){
            [weakSelf billingTest];
        });
#endif
    }
    return self;
}

- (void)dealloc {
#if TEST_BILLING_STATE
    notify_cancel(_notifyToken);
#endif
}

#if TEST_BILLING_STATE
- (void)billingTest {
    if (_state == BillingStateFree) {
        [self updateWithRecord:@{@"mode":@"paid"}];
    } else if (_state == BillingStateTrial) {
        [self updateWithRecord:@{@"mode":@"free"}];
    } else {
        [self updateWithRecord:@{@"mode":@"trial", @"trialEndDate":[[[NSDate date] dateByAddingDays:@1] JSONString]}];
    }
}
#endif

// Must be called on _store.moc
- (LocalBilling *)localBilling:(NSManagedObjectContext *)moc {
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalBilling"];
    fetch.fetchLimit = 1;
    
    LocalBilling *billing = [[moc executeFetchRequest:fetch error:NULL] firstObject];
    if (!billing) {
        // If we have no billing info, start a 30 day trial until we can get some more info from the server
        billing = [NSEntityDescription insertNewObjectForEntityForName:@"LocalBilling" inManagedObjectContext:moc];
        billing.billingState = @(BillingStateTrial);
        NSDate *now = [NSDate date];
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *then = [cal dateByAddingUnit:NSCalendarUnitDay value:30 toDate:now options:0];
        billing.endDate = then;
        [moc save:NULL];
    }
    
    return billing;
}

- (void)notifyStateChange {
    if (!_store) {
        return;
    }
    NSDictionary *userInfo = @{ DataStoreMetadataKey : _store.metadataStore };
    [_store postNotification:DataStoreDidUpdateMetadataNotification userInfo:userInfo];
    [_store postNotification:DataStoreBillingStateDidChangeNotification userInfo:nil];
}

- (void)billingExpired:(NSTimer *)timer {
    _expirationTimer = nil;
    _state = BillingStateFree;
    [_store performWrite:^(NSManagedObjectContext *moc) {
        LocalBilling *billing = [self localBilling:moc];
        billing.billingState = @(BillingStateFree);
        [moc save:NULL];
    }];
    [self notifyStateChange];
}

- (void)checkForBillingExpiration {
    [_expirationTimer invalidate];
    
    if (_state == BillingStateTrial) {
        NSTimeInterval expires = [_trialEndDate timeIntervalSinceNow];
        if (expires <= 0) {
            [self billingExpired:nil];
        } else {
            _expirationTimer = [NSTimer scheduledTimerWithTimeInterval:expires weakTarget:self selector:@selector(billingExpired:) userInfo:nil repeats:NO];
        }
    }
}

- (void)updateWithRecord:(NSDictionary *)record {
    DebugLog(@"%@", record);
    RunOnMain(^{
        BillingState newState = BillingStateTrial;
        if ([record[@"mode"] isEqualToString:@"paid"]) {
            newState = BillingStatePaid;
        } else if ([record[@"mode"] isEqualToString:@"free"]) {
            newState = BillingStateFree;
        }
        
        NSDate *newDate = nil;
        if (record[@"trialEndDate"] != [NSNull null]) {
            newDate = [NSDate dateWithJSONString:record[@"trialEndDate"]];
        }

        if (_state != newState || ![NSObject object:_trialEndDate isEqual:newDate])
        {
            _state = newState;
            _trialEndDate = newDate;
            [_store performWrite:^(NSManagedObjectContext *moc) {
                LocalBilling *billing = [self localBilling:moc];
                billing.billingState = @(newState);
                billing.endDate = newDate;
                [moc save:NULL];
            }];
            [self checkForBillingExpiration];
            [self notifyStateChange];
        }
        
        NSString *subscriptionRefreshHash = record[@"manageSubscriptionsRefreshHash"];
        if (![NSObject object:subscriptionRefreshHash isEqual:_subscriptionRefreshHash]) {
            self.subscriptionRefreshHash = subscriptionRefreshHash;
            [[NSNotificationCenter defaultCenter] postNotificationName:BillingSubscriptionRefreshHashDidChangeNotification object:self];
        }
    });
}

- (BOOL)isLimited {
    Auth *auth = _store.auth;
    if (auth.account.publicReposOnly) {
        return YES;
    } else {
        return _state == BillingStateFree;
    }
}

- (BillingState)state {
    Auth *auth = _store.auth;
    if (auth.account.publicReposOnly) {
        return BillingStatePaid;
    } else {
        return _state;
    }
}

@end

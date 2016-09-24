//
//  Billing.m
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Billing.h"

#import "DataStoreInternal.h"
#import "LocalBilling.h"
#import "Extras.h"

@interface Billing ()

@property NSTimer *expirationTimer;

@end

@implementation Billing

- (id)initWithDataStore:(DataStore *)store {
    if (self = [super init]) {
        self.store = store;
        [_store.moc performBlockAndWait:^{
            LocalBilling *billing = [self localBilling];
            
            _state = [billing.billingState integerValue];
            _trialEndDate = billing.endDate;
            
            DebugLog(@"Billing state %td trialEndDate %@", _state, _trialEndDate);
            
            [self checkForBillingExpiration];
        }];
    }
    return self;
}

// Must be called on _store.moc
- (LocalBilling *)localBilling {
    NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:@"LocalBilling"];
    fetch.fetchLimit = 1;
    
    LocalBilling *billing = [[_store.moc executeFetchRequest:fetch error:NULL] firstObject];
    if (!billing) {
        // If we have no billing info, start a 30 day trial until we can get some more info from the server
        billing = [NSEntityDescription insertNewObjectForEntityForName:@"LocalBilling" inManagedObjectContext:_store.moc];
        billing.billingState = @(BillingStateTrial);
        NSDate *now = [NSDate date];
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSDate *then = [cal dateByAddingUnit:NSCalendarUnitDay value:30 toDate:now options:0];
        billing.endDate = then;
        [_store.moc save:NULL];
    }
    
    return billing;
}

- (void)notifyStateChange {
    NSDictionary *userInfo = @{ DataStoreMetadataKey : _store.metadataStore };
    [_store postNotification:DataStoreDidUpdateMetadataNotification userInfo:userInfo];
    [_store postNotification:DataStoreBillingStateDidChangeNotification userInfo:nil];
}

- (void)billingExpired:(NSTimer *)timer {
    _expirationTimer = nil;
    _state = BillingStateFree;
    [_store.moc performBlock:^{
        LocalBilling *billing = [self localBilling];
        billing.billingState = @(BillingStateFree);
        [_store.moc save:NULL];
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
            _expirationTimer = [NSTimer scheduledTimerWithTimeInterval:expires target:self selector:@selector(billingExpired:) userInfo:nil repeats:NO];
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
            [_store.moc performBlock:^{
                LocalBilling *billing = [self localBilling];
                billing.billingState = @(newState);
                billing.endDate = newDate;
                [_store.moc save:NULL];
            }];
            [self checkForBillingExpiration];
            [self notifyStateChange];
        }
    });
}

- (BOOL)isLimited {
    return _state == BillingStateFree;
}

@end

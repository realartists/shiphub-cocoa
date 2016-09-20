//
//  Billing.h
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DataStore;

typedef NS_ENUM(NSInteger, BillingState) {
    BillingStateTrial = 0,
    BillingStateFree = 1,
    BillingStatePaid = 2
};

@interface Billing : NSObject

- (id)initWithDataStore:(DataStore *)store;

@property (weak) DataStore *store;

// Returns YES if access to private repos is restricted (free mode)
@property (readonly, getter=isLimited) BOOL limited;

@property (readonly) BillingState state;
@property (readonly) NSDate *trialEndDate;

- (void)updateWithRecord:(NSDictionary *)record;

@end

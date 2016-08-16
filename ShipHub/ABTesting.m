//
//  ABTesting.m
//  ShipHub
//
//  Created by James Howard on 8/16/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "ABTesting.h"

@implementation ABTesting

+ (ABTesting *)sharedTesting {
    static dispatch_once_t onceToken;
    static ABTesting *testing;
    dispatch_once(&onceToken, ^{
        testing = [ABTesting new];
    });
    return testing;
}

static BOOL boolWithProbability(double probability) {
    if (probability == 1.0) return YES;
    else if (probability == 0.0) return NO;
    
    uint32_t r = arc4random();
    double d = (double)r / (double)UINT32_MAX;
    return d < probability;
}

- (BOOL)usesBrowserBasedOAuth {
    CFStringRef key = CFSTR("AB.UsesBrowserBasedOAuth");
    Boolean exists = false;
    Boolean usesBrowserBasedOAuth = CFPreferencesGetAppBooleanValue(key, kCFPreferencesCurrentApplication, &exists);
    
    if (!exists) {
        usesBrowserBasedOAuth = boolWithProbability(1.0);
        [[NSUserDefaults standardUserDefaults] setBool:usesBrowserBasedOAuth forKey:(__bridge NSString *)key];
    }
    
    return usesBrowserBasedOAuth;
}

@end

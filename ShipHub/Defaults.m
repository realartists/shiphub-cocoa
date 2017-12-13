//
//  Defaults.m
//  Ship
//
//  Created by James Howard on 6/4/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "Defaults.h"

@implementation Defaults

+ (NSUserDefaults *)defaults {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSUserDefaults standardUserDefaults] registerDefaults:
         @{ DefaultsLocalStoragePathKey : [DefaultsLibraryPath() stringByAppendingPathComponent:@"LocalStore"],
     @"InactiveMilestones.Collapsed" : @YES,
#if DEBUG
     @"WebKitDeveloperExtras" : @YES,
#endif
     @"NSUseTextDragAlerts" : @NO // XXX: This is a gross hack to suppress an alert panel shown by NSTextView when dragging in large attachments.
     }];
    });
    return [NSUserDefaults standardUserDefaults];
}

@end

NSString *const DefaultsAnalyticsIDKey = @"AnalyticsID";
NSString *const DefaultsAnalyticsCohortKey = @"AnalyticsCohort";
NSString *const DefaultsLocalStoragePathKey = @"LocalStorage";
NSString *const DefaultsLastUsedAccountKey = @"LastLoginPair";
NSString *const DefaultsDisableAutoWatchKey = @"DisableAutoWatch";
NSString *const DefaultsShipHostKey = @"ShipHost";
NSString *const DefaultsGHHostKey = @"GHHost";
NSString *const DefaultsPullRequestsEnabledKey = @"EnablePR";

NSString *const DefaultsSimulateConflictsKey = @"SimulateConflicts";

@implementation NSUserDefaults (Conveniences)

- (NSInteger)integerForKey:(NSString *)defaultName fallback:(NSInteger)defaultValue {
    id obj = [self objectForKey:defaultName];
    if ([obj respondsToSelector:@selector(integerValue)]) {
        return [obj integerValue];
    }
    return defaultValue;
}
- (NSString *)stringForKey:(NSString *)defaultName fallback:(NSString *)defaultValue {
    id obj = [self objectForKey:defaultName];
    if ([obj isKindOfClass:[NSString class]]) {
        return obj;
    } else if ([obj respondsToSelector:@selector(stringValue)]) {
        return [obj stringValue];
    }
    return defaultValue;
}

@end

NSString *DefaultShipHost(void) {
    return [[Defaults defaults] stringForKey:DefaultsShipHostKey fallback:@"hub.realartists.com"];
}

NSString *DefaultGHHost(void) {
    return [[Defaults defaults] stringForKey:DefaultsGHHostKey fallback:@"api.github.com"];
}

BOOL DefaultsHasCustomShipHost(void) {
    return [[Defaults defaults] stringForKey:DefaultsShipHostKey] != nil;
}

extern BOOL DefaultsPullRequestsEnabled(void) {
    return YES;
}

extern NSString *DefaultsLibraryPath(void) {
#if TARGET_REVIEWED_BY_ME
    return [@"~/Library/RealArtists/ReviewedByMe" stringByExpandingTildeInPath];
#else
    return [@"~/Library/RealArtists/Ship2" stringByExpandingTildeInPath];
#endif
}

extern BOOL IsShipApp(void) {
#if TARGET_REVIEWED_BY_ME
    return NO;
#else
    return YES;
#endif
}

extern BOOL IsReviewedByMeApp(void) {
#if TARGET_REVIEWED_BY_ME
    return YES;
#else
    return NO;
#endif
}

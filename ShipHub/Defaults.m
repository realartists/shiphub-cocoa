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
  @{ DefaultsLocalStoragePathKey : @"~/Library/RealArtists/ShipHub/LocalStore",
     @"InactiveMilestones.Collapsed" : @YES,
#if DEBUG
     @"WebKitDeveloperExtras" : @YES,
#endif
     @"NSUseTextDragAlerts" : @NO, // XXX: This is a gross hack to suppress an alert panel shown by NSTextView when dragging in large attachments.
     DefaultsServerKey: @"api.github.com",
     }];
    });
    return [NSUserDefaults standardUserDefaults];
}

@end

NSString *const DefaultsLocalStoragePathKey = @"LocalStorage";
NSString *const DefaultsLastUsedAccountKey = @"LastLogin";
NSString *const DefaultsDisableAutoWatchKey = @"DisableAutoWatch";

NSString *const DefaultsSimulateConflictsKey = @"SimulateConflicts";
NSString *const DefaultsServerKey = @"Server";

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

BOOL ServerEnvironmentIsLocal() {
    return [[[Defaults defaults] stringForKey:DefaultsServerKey] isEqualToString:@"api.github.com"];
}

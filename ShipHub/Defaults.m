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
     @"NSUseTextDragAlerts" : @NO // XXX: This is a gross hack to suppress an alert panel shown by NSTextView when dragging in large attachments.
     }];
    });
    return [NSUserDefaults standardUserDefaults];
}

@end

NSString *const DefaultsLocalStoragePathKey = @"LocalStorage";
NSString *const DefaultsLastUsedAccountKey = @"LastLogin";
NSString *const DefaultsDisableAutoWatchKey = @"DisableAutoWatch";

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

NSString *ServerEnvironmentToString(ServerEnvironment e) {
    switch (e) {
        case ServerEnvironmentLocal: return @"Local";
        case ServerEnvironmentDevelopment: return @"Development";
        case ServerEnvironmentJW: return @"JW";
        case ServerEnvironmentStaging: return @"Staging";
        case ServerEnvironmentProduction: return @"Production";
    }
}
ServerEnvironment ServerEnvironmentFromString(NSString *environment) {
    if ([environment isEqualToString:@"Local"]) {
        return ServerEnvironmentLocal;
    } else if ([environment isEqualToString:@"Development"]) {
        return ServerEnvironmentDevelopment;
    } else if ([environment isEqualToString:@"JW"]) {
        return ServerEnvironmentJW;
    } else if ([environment isEqualToString:@"Staging"]) {
        return ServerEnvironmentStaging;
    } else {
        return ServerEnvironmentProduction;
    }
}

static NSInteger s_environment = -1;

ServerEnvironment DefaultsServerEnvironment() {
    @synchronized ([Defaults defaults]) {
        if (s_environment == -1) {
            // Establish environment from Info.plist
            NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
            NSString *env = info[@"ServerEnvironment"];
            s_environment = ServerEnvironmentFromString(env);
            NSLog(@"Using server environment %@", ServerEnvironmentToString(s_environment));
        }
        return s_environment;
    }
}

//
//  Defaults.h
//  Ship
//
//  Created by James Howard on 6/4/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Defaults : NSObject

+ (NSUserDefaults *)defaults;

@end

extern NSString *const DefaultsLastUsedAccountKey;

extern NSString *const DefaultsLocalStoragePathKey;

extern NSString *const DefaultsDisableAutoWatchKey;

// Debugging defaults
extern NSString *const DefaultsSimulateConflictsKey;

@interface NSUserDefaults (Conveniences)

- (NSInteger)integerForKey:(NSString *)defaultName fallback:(NSInteger)defaultValue;
- (NSString *)stringForKey:(NSString *)defaultName fallback:(NSString *)defaultValue;

@end

typedef NS_ENUM(NSInteger, ServerEnvironment) {
    ServerEnvironmentProduction,
    ServerEnvironmentStaging,
    ServerEnvironmentDevelopment,
    ServerEnvironmentJW,
    ServerEnvironmentLocal,
};

extern NSString *ServerEnvironmentToString(ServerEnvironment);
extern ServerEnvironment ServerEnvironmentFromString(NSString *environment);

extern ServerEnvironment DefaultsServerEnvironment(); // Returns the configured server environment
extern void OverrideDefaultsServerEnvironment(ServerEnvironment);

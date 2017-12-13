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

extern NSString *const DefaultsAnalyticsIDKey;
extern NSString *const DefaultsAnalyticsCohortKey;

extern NSString *const DefaultsLastUsedAccountKey;

extern NSString *const DefaultsLocalStoragePathKey;

extern NSString *const DefaultsDisableAutoWatchKey;

// Debugging defaults
extern NSString *const DefaultsSimulateConflictsKey;
extern NSString *const DefaultsShipHostKey;
extern NSString *const DefaultsGHHostKey;

@interface NSUserDefaults (Conveniences)

- (NSInteger)integerForKey:(NSString *)defaultName fallback:(NSInteger)defaultValue;
- (NSString *)stringForKey:(NSString *)defaultName fallback:(NSString *)defaultValue;

@end

extern NSString *DefaultShipHost(void);
extern NSString *DefaultGHHost(void);

extern BOOL DefaultsPullRequestsEnabled(void);

extern BOOL DefaultsHasCustomShipHost(void);

extern NSString *DefaultsLibraryPath(void);

extern BOOL IsShipApp(void);
extern BOOL IsReviewedByMeApp(void);

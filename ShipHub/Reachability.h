//
//  Reachability.h
//  Ship
//
//  Created by James Howard on 5/28/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Reachability : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) BOOL receivedFirstUpdate;
@property (nonatomic, readonly, getter=isReachable) BOOL reachable;
@property (nonatomic, getter=isForcingOffline) BOOL forceOffline;

@end

extern NSString *const ReachabilityDidChangeNotification;
extern NSString *const ReachabilityKey; // => bool

//
//  Reachability.m
//  Ship
//
//  Created by James Howard on 5/28/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "Reachability.h"
#import "ServerConnection.h"
#import "KSReachability.h"

NSString *const ReachabilityDidChangeNotification = @"ReachabilityDidChangeNotification";
NSString *const ReachabilityKey = @"ReachabilityKey";

NSString *const ReachabilityRetryOperationsNotification = @"ReachabilityRetryOperationsNotification";

@interface Reachability () {
    BOOL _forceOffline;
}

@property (strong) KSReachability *impl;

@end

@implementation Reachability

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    static Reachability *reachability;
    dispatch_once(&onceToken, ^{
        reachability = [[Reachability alloc] init];
    });
    return reachability;
}

- (instancetype)init {
    if (self = [super init]) {
        NSString *host = nil; //[[ServerConnection baseURL] host];
        _impl = [KSReachability reachabilityToHost:host];
        __weak __typeof(self) weakSelf = self;
        _impl.onReachabilityChanged = ^(KSReachability* reachability) {
            Reachability *strongSelf = weakSelf;
            BOOL reachable = [strongSelf isReachable];
            strongSelf->_receivedFirstUpdate = YES;
            
            [[NSNotificationCenter defaultCenter] postNotificationName:ReachabilityDidChangeNotification object:strongSelf userInfo:@{ReachabilityKey:@(reachable)}];
        };
    }
    return self;
}

- (BOOL)isReachable {
    return !_forceOffline && _impl.reachable;
}

- (BOOL)isForcingOffline {
    return _forceOffline;
}

- (void)setForceOffline:(BOOL)forceOffline {
    if (_forceOffline != forceOffline) {
        BOOL oldReachable = [self isReachable];
        _forceOffline = forceOffline;
        BOOL newReachable = [self isReachable];
        
        if (oldReachable != newReachable) {
            [[NSNotificationCenter defaultCenter] postNotificationName:ReachabilityDidChangeNotification object:self userInfo:@{ReachabilityKey:@(newReachable)}];
        }
    }
}

@end

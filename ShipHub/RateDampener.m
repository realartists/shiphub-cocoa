//
//  RateDampener.m
//  ShipHub
//
//  Created by James Howard on 9/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "RateDampener.h"

@interface RateDampener ()

@property double windowStart;
@property NSInteger windowCount;

@property (copy) dispatch_block_t queued;
@property NSTimer *timer;

@end

@implementation RateDampener

- (id)init {
    if (self = [super init]) {
        _windowDuration = 1.0;
        _windowWidth = 1;
    }
    return self;
}

- (void)timerFired:(NSTimer *)timer {
    _timer = nil;
    
    _windowStart = CACurrentMediaTime();
    _windowCount = 1;
    
    dispatch_block_t qd = self.queued;
    self.queued = nil;
    if (qd) {
        qd();
    }
}

- (void)addBlock:(dispatch_block_t)block {
    double now = CACurrentMediaTime();
    NSTimeInterval diff = now - _windowStart;
    if (diff > _windowDuration) {
        _windowStart = now;
        _windowCount = 0;
        [_timer invalidate];
        _timer = nil;
        self.queued = nil;
    }
    
    if (_windowCount < _windowWidth) {
        _windowCount++;
        block();
    } else {
        self.queued = block;
        if (!_timer) {
            _timer = [NSTimer scheduledTimerWithTimeInterval:_windowDuration target:self selector:@selector(timerFired:) userInfo:nil repeats:NO];
        }
    }
}

@end

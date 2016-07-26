//
//  CAExtras.m
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "CAExtras.h"

@interface AnimationCompleter : NSObject

@property (nonatomic, copy) void (^completion)(BOOL finished);

@end

@implementation AnimationCompleter

- (void)animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
    _completion(flag);
}

@end

@implementation CALayer (AnimationCompletion)

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key completion:(void (^)(BOOL finished))completion {
    if (completion) {
        AnimationCompleter *completer = [AnimationCompleter new];
        completer.completion = completion;
        anim.delegate = (id)completer; // retains completer
    }
    [self addAnimation:anim forKey:key];
}

@end

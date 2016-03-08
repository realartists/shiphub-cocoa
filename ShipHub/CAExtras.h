//
//  CAExtras.h
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface CALayer (AnimationCompletion)

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key completion:(void (^)(BOOL finished))completion;

@end
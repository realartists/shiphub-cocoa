//
//  RateDampener.h
//  ShipHub
//
//  Created by James Howard on 9/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/* 
 RateDampener lets a fixed number of blocks execute within a time window, 
 and then when you're over the number for a given window, waits until the
 next time window opens before running the most recent block.
 
 IMPORTANT: Not all dampened blocks are guaranteed to execute!
*/

@interface RateDampener : NSObject

@property NSTimeInterval windowDuration; // how long a window lasts. default 1.0
@property NSInteger windowWidth; // maximum number of blocks to execute within the window. default 1

- (void)addBlock:(dispatch_block_t)block;

@end

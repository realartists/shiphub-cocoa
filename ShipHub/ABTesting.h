//
//  ABTesting.h
//  ShipHub
//
//  Created by James Howard on 8/16/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ABTesting : NSObject

+ (ABTesting *)sharedTesting;

@property (nonatomic) BOOL usesBrowserBasedOAuth;

@end

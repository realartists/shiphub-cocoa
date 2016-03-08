//
//  NSURLSession+PinnedSession.h
//  ShipHub
//
//  Created by James Howard on 3/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURLSession (PinnedSession)

+ (NSURLSession *)pinnedSession; // returns an NSURLSession that does certificate pinning for specific known hosts

@end

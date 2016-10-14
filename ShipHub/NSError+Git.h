//
//  NSError+Git.h
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (Git)

+ (NSError *)gitError; // creates an NSError with the last git2 error to occur

@end

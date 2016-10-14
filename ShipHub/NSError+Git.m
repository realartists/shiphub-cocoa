//
//  NSError+Git.m
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "NSError+Git.h"

#import <git2.h>

@implementation NSError (Git)

+ (NSError *)gitError {
    const git_error *err = giterr_last();
    if (!err) return nil;
    
    return [NSError errorWithDomain:@"git" code:err->klass userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:err->message]}];
}

@end

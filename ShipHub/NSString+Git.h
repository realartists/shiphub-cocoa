//
//  NSString+Git.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <git2.h>

@interface NSString (Git)

+ (NSString *)stringWithGitBlob:(const git_blob *)blob;
+ (NSString *)stringWithGitBuf:(const git_buf *)buf;

@end

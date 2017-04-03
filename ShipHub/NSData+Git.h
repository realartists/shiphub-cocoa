//
//  NSData+Git.h
//  ShipHub
//
//  Created by James Howard on 4/3/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <git2.h>

@interface NSData (Git)

+ (NSData *)dataWithGitBlob:(const git_blob *)blob;

@end

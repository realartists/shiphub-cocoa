//
//  NSData+Git.m
//  ShipHub
//
//  Created by James Howard on 4/3/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "NSData+Git.h"

@implementation NSData (Git)

+ (NSData *)dataWithGitBlob:(const git_blob *)blob {
    const void *rawContents = git_blob_rawcontent(blob);
    size_t rawContentsLength = git_blob_rawsize(blob);
    return [[NSData alloc] initWithBytes:rawContents length:rawContentsLength];
}

@end

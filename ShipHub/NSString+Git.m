//
//  NSString+Git.m
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "NSString+Git.h"

@implementation NSString (Git)

+ (NSString *)stringWithGitOid:(const git_oid *)oid {
    char buf[GIT_OID_HEXSZ];
    git_oid_fmt(buf, oid);
    return [[NSString alloc] initWithBytes:buf length:GIT_OID_HEXSZ encoding:NSASCIIStringEncoding];
}

+ (NSString *)stringWithGitBlob:(const git_blob *)blob {
    const void *rawContents = git_blob_rawcontent(blob);
    size_t rawContentsLength = git_blob_rawsize(blob);
    return [[NSString alloc] initWithBytes:rawContents length:rawContentsLength encoding:NSUTF8StringEncoding];
}

+ (NSString *)stringWithGitBuf:(const git_buf *)buf {
    if (!buf->ptr) return nil;
    if (buf->size == 0) return @"";
    
    return [[NSString alloc] initWithBytes:buf->ptr length:buf->size encoding:NSUTF8StringEncoding];
}

@end

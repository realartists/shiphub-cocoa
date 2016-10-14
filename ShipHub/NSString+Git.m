//
//  NSString+Git.m
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "NSString+Git.h"

@implementation NSString (Git)

static NSDictionary *encodingOpts() {
    static dispatch_once_t onceToken;
    static NSDictionary *stringOpts;
    dispatch_once(&onceToken, ^{
        stringOpts = @{
            NSStringEncodingDetectionSuggestedEncodingsKey : @[@(NSUTF8StringEncoding)],
            NSStringEncodingDetectionAllowLossyKey : @NO,
            NSStringEncodingDetectionLikelyLanguageKey : @"en"
        };
    });
    return stringOpts;
}

+ (NSString *)stringWithGitBlob:(const git_blob *)blob {
    const void *rawContents = git_blob_rawcontent(blob);
    size_t rawContentsLength = git_blob_rawsize(blob);
    
    NSData *data = [NSData dataWithBytes:rawContents length:rawContentsLength];
    NSString *result = nil;
    [NSString stringEncodingForData:data encodingOptions:encodingOpts() convertedString:&result usedLossyConversion:NULL];
    
    return result;
}

+ (NSString *)stringWithGitBuf:(const git_buf *)buf {
    if (!buf->ptr) return nil;
    if (buf->size == 0) return @"";
    
    NSData *data = [NSData dataWithBytes:buf->ptr length:buf->size];
    NSString *result = nil;
    [NSString stringEncodingForData:data encodingOptions:encodingOpts() convertedString:&result usedLossyConversion:NULL];
    return result;
}

@end

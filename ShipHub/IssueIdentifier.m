//
//  NSString+IssueIdentifier.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueIdentifier.h"

@implementation NSString (IssueIdentifier)

+ (NSString *)issueIdentifierWithOwner:(NSString *)ownerLogin repo:(NSString *)repoName number:(NSNumber *)number
{
    return [NSString stringWithFormat:@"%@/%@#%@", ownerLogin, repoName, number];
}

- (BOOL)isIssueIdentifier {
    static NSRegularExpression *re = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"\\w[\\w\\-\\d]*/\\w[\\w\\-\\d]*#\\d+" options:0 error:NULL];
    });
    return [re numberOfMatchesInString:self options:0 range:NSMakeRange(0, self.length)] == 1;
}

- (NSString *)issueRepoOwner {
    NSRange firstDelim = [self rangeOfString:@"/"];
    if (firstDelim.length == 0) return nil;
    NSRange range = NSMakeRange(0, firstDelim.location);
    return [self substringWithRange:range];
}

- (NSString *)issueRepoName {
    NSRange firstDelim = [self rangeOfString:@"/"];
    NSRange secondDelim = [self rangeOfString:@"#"];
    if (firstDelim.length == 0 || secondDelim.length == 0) {
        return nil;
    }
    return [self substringWithRange:NSMakeRange(NSMaxRange(firstDelim), secondDelim.location - firstDelim.location)];
}

- (NSNumber *)issueNumber {
    NSRange firstDelim = [self rangeOfString:@"#"];
    if (firstDelim.length == 0) return nil;
    NSRange range = NSMakeRange(NSMaxRange(firstDelim), self.length - NSMaxRange(firstDelim));
    int64_t v = [[self substringWithRange:range] longLongValue];
    if (v > 0) {
        return @(v);
    } else {
        return nil;
    }
}

@end

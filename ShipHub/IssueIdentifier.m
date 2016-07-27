//
//  NSString+IssueIdentifier.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueIdentifier.h"

#import "Auth.h"
#import "DataStore.h"
#import "Extras.h"

@implementation NSString (IssueIdentifier)

+ (NSString *)issueIdentifierWithGitHubURL:(NSURL *)URL {
    // https://github.com/realartists/shiphub-server/issues/22
    
    NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    NSString *path = [components path];
    
    NSArray *pathParts = [path componentsSeparatedByString:@"/"];
    if (pathParts.count != 5 || ![pathParts[3] isEqualToString:@"issues"]) {
        return nil;
    }
    
    NSString *owner = pathParts[1];
    NSString *repo = pathParts[2];
    NSString *numberStr = pathParts[4];
    NSNumber *number = @([numberStr longLongValue]);
    
    return [self issueIdentifierWithOwner:owner repo:repo number:number];
}

+ (NSString *)issueIdentifierWithOwner:(NSString *)ownerLogin repo:(NSString *)repoName number:(NSNumber *)number
{
    return [NSString stringWithFormat:@"%@/%@#%@", ownerLogin, repoName, number];
}

+ (NSRegularExpression *)issueIdentifierRE {
    static NSRegularExpression *re = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"\\w[\\w\\-\\d]*/\\w[\\w\\-\\d]*#\\d+" options:0 error:NULL];
    });
    return re;
}

+ (NSRegularExpression *)gitHubURLRE {
    static NSRegularExpression *re = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"http(?:s?)://[\\w\\.\\-\\d]+/\\w[\\w\\-\\d]*/\\w[\\w\\-\\d]*/issues/\\d+" options:0 error:NULL];
    });
    return re;
}

- (BOOL)isIssueIdentifier {
    return [[NSString issueIdentifierRE] numberOfMatchesInString:self options:0 range:NSMakeRange(0, self.length)] == 1;
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
    return [self substringWithRange:NSMakeRange(NSMaxRange(firstDelim), secondDelim.location - NSMaxRange(firstDelim))];
}

- (NSString *)issueRepoFullName {
    NSString *owner = [self issueRepoOwner];
    NSString *name = [self issueRepoName];
    
    if (!owner || !name) return nil;
    
    return [NSString stringWithFormat:@"%@/%@", owner, name];
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

- (NSURL *)issueGitHubURL {
    AuthAccount *account = [[[DataStore activeStore] auth] account];
    NSString *host = [account.ghHost stringByReplacingOccurrencesOfString:@"api." withString:@""] ?: @"github.com";
    
    
    NSString *URLStr = [NSString stringWithFormat:@"https://%@/%@/%@/issues/%@", host, [self issueRepoOwner], [self issueRepoName], [self issueNumber]];
    
    return [NSURL URLWithString:URLStr];
}

#if TARGET_OS_MAC

- (NSDictionary *)pasteboardData {
    NSAssert([self isIssueIdentifier], @"Must be an IssueIdentifier");
    
    NSString *contents = self;
    NSURL *URL = [self issueGitHubURL];
    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:contents attributes:@{NSLinkAttributeName: URL}];
    
    return @{ @"plain": contents, @"rtf": attrStr, @"URL" : URL};
}

- (NSDictionary *)pasteboardDataWithTitle:(NSString *)title {
    if ([title length] == 0) {
        return [self pasteboardData];
    }
    
    NSString *contents = [self stringByAppendingFormat:@" %@", title];
    NSURL *URL = [self issueGitHubURL];
    NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:contents attributes:@{NSLinkAttributeName: URL}];
    
    return @{ @"plain": contents, @"rtf": attrStr, @"URL" : URL};
}

- (void)copyIssueIdentifierToPasteboard:(NSPasteboard *)pboard {
    if ([self isIssueIdentifier]) {
        [pboard clearContents];
        NSDictionary *d = [self pasteboardData];
        [pboard writeObjects:@[[MultiRepresentationPasteboardData representationWithArray:@[d[@"rtf"], d[@"URL"]]]]];
    }
}

- (void)copyIssueIdentifierToPasteboard:(NSPasteboard *)pboard withTitle:(NSString *)title {
    if ([self isIssueIdentifier]) {
        [pboard clearContents];
        NSDictionary *d = [self pasteboardDataWithTitle:title];
        [pboard writeObjects:@[[MultiRepresentationPasteboardData representationWithArray:@[d[@"rtf"], d[@"URL"]]]]];
    }
}

- (void)copyIssueGitHubURLToPasteboard:(NSPasteboard *)pboard {
    if ([self isIssueIdentifier]) {
        [pboard clearContents];
        NSURL *URL = [self issueGitHubURL];
        NSAttributedString *attr = [[NSAttributedString alloc] initWithString:[URL description] attributes:@{NSLinkAttributeName: URL}];
        [pboard writeObjects:@[[MultiRepresentationPasteboardData representationWithArray:@[attr, URL]]]];
    }
}

+ (void)copyIssueIdentifiers:(NSArray<NSString *> *)identifiers toPasteboard:(NSPasteboard *)pboard {
    if ([identifiers count] == 0) {
        [[identifiers firstObject] copyIssueIdentifierToPasteboard:pboard];
        return;
    }
    
    NSMutableAttributedString *attr = [NSMutableAttributedString new];
    
    NSUInteger i = 0;
    NSUInteger count = identifiers.count;
    for (id identifier in identifiers) {
        NSDictionary *d = [identifier pasteboardData];
        [attr appendAttributedString:d[@"rtf"]];
        i++;
        if (i != count) {
            [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
        }
    }
    
    [pboard clearContents];
    [pboard writeObjects:@[attr]];
}

+ (void)copyIssueIdentifiers:(NSArray<NSString *> *)identifiers withTitles:(NSArray<NSString *> *)titles toPasteboard:(NSPasteboard *)pboard {
    NSMutableAttributedString *attr = [NSMutableAttributedString new];
    
    NSUInteger i = 0;
    NSUInteger count = identifiers.count;
    for (id identifier in identifiers) {
        NSDictionary *d = [identifier pasteboardDataWithTitle:titles[i]];
        [attr appendAttributedString:d[@"rtf"]];
        i++;
        if (i != count) {
            [attr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
        }
    }
    
    [pboard clearContents];
    [pboard writeObjects:@[attr]];
}

+ (BOOL)canReadIssueIdentifiersFromPasteboard:(NSPasteboard *)pboard {
    return [[self readIssueIdentifiersFromPasteboard:pboard] count] > 0;
}

+ (NSArray<NSString *> *)readIssueIdentifiersFromPasteboard:(NSPasteboard *)pboard {
    NSString *plainText = [pboard stringForType:NSPasteboardTypeString];
    if (!plainText) return nil;
    NSRegularExpression *re1 = [NSString issueIdentifierRE];
    NSRegularExpression *re2 = [NSString gitHubURLRE];
    NSMutableArray *identifiers = [NSMutableArray new];
    [re1 enumerateMatchesInString:plainText options:0 range:NSMakeRange(0, plainText.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        NSString *substr = [plainText substringWithRange:result.range];
        NSAssert([substr isIssueIdentifier], @"check range");
        [identifiers addObject:substr];
    }];
    [re2 enumerateMatchesInString:plainText options:0 range:NSMakeRange(0, plainText.length) usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
        NSString *substr = [plainText substringWithRange:result.range];
        @try {
            NSURL *URL = [[NSURL alloc] initWithString:substr];
            NSString *issueIdentifier = [NSString issueIdentifierWithGitHubURL:URL];
            [identifiers addObject:issueIdentifier];
        } @catch (id exc) { }
    }];
    return identifiers;
}
#endif

@end


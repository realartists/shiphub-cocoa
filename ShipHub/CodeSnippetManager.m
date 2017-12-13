//
//  CodeSnippetManager.m
//  ShipHub
//
//  Created by James Howard on 8/16/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "CodeSnippetManager.h"

#import "Auth.h"
#import "AppAdapter.h"
#import "Extras.h"
#import "ServerConnection.h"

NSString *const CodeSnippetManagerErrorDomain = @"CodeSnippetManager";

@implementation CodeSnippetKey {
    NSUInteger _hash;
}

+ (instancetype)keyWithRepoFullName:(NSString *)repoFullName sha:(NSString *)sha path:(NSString *)path startLine:(NSInteger)startLine endLine:(NSInteger)endLine
{
    CodeSnippetKey *key = [[[self class] alloc] init];
    key->_repoFullName = repoFullName;
    key->_sha = sha;
    key->_path = path;
    key->_startLine = startLine;
    key->_endLine = endLine;
    key->_hash = [[key description] hash];
    return key;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"%@/blob/%@/%@#L%td-L%td", _repoFullName, _sha, _path, _startLine, _endLine];
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (NSUInteger)hash {
    return _hash;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[CodeSnippetKey class]]) return NO;
    CodeSnippetKey *o = object;
    return _startLine == o->_startLine && _endLine == o->_endLine && [_sha isEqual:o->_sha] && [_path isEqual:o->_path] && [_repoFullName isEqual:o->_repoFullName];
}

@end

@implementation CodeSnippetManager

+ (instancetype)sharedManager {
    static dispatch_once_t onceToken;
    static id manager;
    dispatch_once(&onceToken, ^{
        manager = [[[self class] alloc] init];
    });
    return manager;
}

static NSCache *cache() {
    static dispatch_once_t onceToken;
    static NSCache *x;
    dispatch_once(&onceToken, ^{
        x = [NSCache new];
    });
    return x;
}

static NSString *extractSnippet(NSString *wholeFile, NSInteger startLine, NSInteger endLine, NSError *__autoreleasing* outErr) {
    __block NSInteger lineNum = 0;
    __block BOOL finished = NO;
    NSMutableArray *lines = [NSMutableArray new];
    [wholeFile enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        lineNum++;
        if (lineNum >= startLine && lineNum <= endLine) {
            [lines addObject:line];
        }
        if (lineNum >= endLine) {
            *stop = finished = YES;
        }
    }];
    
    if (!finished) {
        if (outErr) {
            *outErr = [NSError errorWithDomain:CodeSnippetManagerErrorDomain code:CodeSnippetManagerErrorCodeLineNotFound userInfo:nil];
        }
    }
    
    return [lines componentsJoinedByString:@"\n"];
}

- (void)loadSnippet:(CodeSnippetKey *)key completion:(void (^)(NSString *, NSError *))completion {
    NSString *snippet = [cache() objectForKey:key];
    if (snippet) {
        completion(snippet, nil);
        return;
    }
    
    Auth *auth = [SharedAppAdapter() auth];
    
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = [[auth account] ghHost];
    comps.path = [NSString stringWithFormat:@"/repos/%@/contents/%@", key.repoFullName, [key.path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]];
    comps.queryItemsDictionary = @{ @"ref" : key.sha };
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:comps.URL];
    req.HTTPMethod = @"GET";
    [req addValue:@"application/vnd.github.v3.raw" forHTTPHeaderField:@"Accept"];
    [auth addAuthHeadersToRequest:req];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *http = (id)response;
        if (!error && http.statusCode != 200) {
            error = [NSError errorWithDomain:CodeSnippetManagerErrorDomain code:CodeSnippetManagerErrorCodeFileNotFound userInfo:nil];
        }
        
        NSString *snip = nil;
        if (!error) {
            NSString *decoded = [[NSString alloc] initWithData:data?:[NSData data] encoding:NSUTF8StringEncoding];
            NSError *snipErr = nil;
            snip = extractSnippet(decoded, key.startLine, key.endLine, &snipErr);
            if (snipErr) {
                error = snipErr;
            }
        }
        
        if (error) {
            ErrLog(@"%@", error);
            completion(nil, error);
        } else {
            [cache() setObject:snip forKey:key];
            completion(snip, nil);
        }
    }] resume];
}

@end

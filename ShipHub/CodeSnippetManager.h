//
//  CodeSnippetManager.h
//  ShipHub
//
//  Created by James Howard on 8/16/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CodeSnippetKey : NSObject <NSCopying>

+ (instancetype)keyWithRepoFullName:(NSString *)repoFullName sha:(NSString *)sha path:(NSString *)path startLine:(NSInteger)startLine endLine:(NSInteger)endLine;

@property (readonly) NSString *repoFullName;
@property (readonly) NSString *sha;
@property (readonly) NSString *path;
@property (readonly) NSInteger startLine;
@property (readonly) NSInteger endLine;

@end

@interface CodeSnippetManager : NSObject

+ (instancetype)sharedManager;

- (void)loadSnippet:(CodeSnippetKey *)key completion:(void (^)(NSString *snippet, NSError *error))completion;

@end

typedef NS_ENUM(NSInteger, CodeSnippetManagerErrorCode) {
    CodeSnippetManagerErrorCodeLineNotFound = -1,
    CodeSnippetManagerErrorCodeFileNotFound = -2
};

extern NSString *const CodeSnippetManagerErrorDomain;

//
//  GitFileSearch.h
//  ShipHub
//
//  Created by James Howard on 6/7/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GitDiffFile;

typedef NS_OPTIONS(NSUInteger, GitFileSearchFlags) {
    GitFileSearchFlagRegex = 1 << 0,
    GitFileSearchFlagCaseInsensitive = 1 << 1,
    GitFileSearchFlagAddedLinesOnly = 1 << 2
};

@interface GitFileSearch : NSObject <NSCopying>

@property (copy) NSString *query;
@property GitFileSearchFlags flags;

@end

@interface GitFileSearchResult : NSObject

@property GitDiffFile *file;
@property NSString *matchedLineText;
@property NSArray<NSTextCheckingResult *> *matchedResults; // ranges within matchedLineText
@property NSInteger matchedLineNumber; // in newFile

@end

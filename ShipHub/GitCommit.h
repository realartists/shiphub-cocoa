//
//  Commit.h
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GitDiff;
@class GitRepo;

@interface GitCommit : NSObject

@property (readonly) NSString *rev;
@property (readonly) NSString *authorName;
@property (readonly) NSString *authorEmail;
@property (readonly) NSDate *date;
@property (readonly) NSString *message;

- (void)loadDiff:(void (^)(GitDiff *diff, NSError *err))completion;

+ (NSArray<GitCommit *> *)commitLogFrom:(NSString *)baseRev to:(NSString *)headRev inRepo:(GitRepo *)repo error:(NSError *__autoreleasing *)error;

// should be called from a background thread
+ (GitDiff *)spanFromCommitRangeStart:(GitCommit *)start end:(GitCommit *)end error:(NSError *__autoreleasing *)error;

@end

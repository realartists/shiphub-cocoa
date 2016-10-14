//
//  PullRequest.h
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Issue;
@class GitDiff;

@interface PullRequest : NSObject

- (instancetype)initWithIssue:(Issue *)issue;

@property (readonly) Issue *issue;

- (NSProgress *)checkout:(void (^)(NSError *error))completion;

@property (readonly) GitDiff *spanDiff; // available after checkout is completed

+ (BOOL)isGitHubFilesURL:(NSURL *)URL;
+ (id)issueIdentifierForGitHubFilesURL:(NSURL *)URL commentIdentifier:(NSNumber *__autoreleasing *)outCommentIdentifier;
+ (NSURL *)gitHubFilesURLForIssueIdentifier:(id)issueIdentifier;
- (NSURL *)gitHubFilesURL;

@end

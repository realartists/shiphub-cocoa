//
//  PRDiffViewController.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IssueWeb2Controller.h"
#import "DiffViewMode.h"

@class GitDiffFile;
@class PRComment;
@class PullRequest;

@interface PRDiffViewController : IssueWeb2Controller

- (void)setPR:(PullRequest *)pr diffFile:(GitDiffFile *)diffFile comments:(NSArray<PRComment *> *)comments;

@property (nonatomic, readonly) PullRequest *pr;
@property (nonatomic, readonly) GitDiffFile *diffFile;
@property (nonatomic, readonly) NSArray<PRComment *> *comments;

@property (nonatomic, assign) DiffViewMode mode;

@end

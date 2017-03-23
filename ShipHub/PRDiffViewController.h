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

@class GitDiff;
@class GitDiffFile;
@class PRComment;
@class PendingPRComment;
@class PullRequest;

@protocol PRDiffViewControllerDelegate;

@interface PRDiffViewController : IssueWeb2Controller

@property (weak) id<PRDiffViewControllerDelegate> delegate;

- (void)setPR:(PullRequest *)pr diffFile:(GitDiffFile *)diffFile diff:(GitDiff *)diff comments:(NSArray<PRComment *> *)comments inReview:(BOOL)inReview scrollInfo:(NSDictionary *)scrollInfo;

- (void)scrollToComment:(PRComment *)comment;
- (void)navigate:(NSDictionary *)options; // See diff.js: App.scrollTo() docstring for options

- (void)focus;

@property (nonatomic, readonly) PullRequest *pr;
@property (nonatomic, readonly) GitDiffFile *diffFile;
@property (nonatomic, readonly) GitDiff *diff;
@property (readonly, getter=isInReview) BOOL inReview;
@property (nonatomic) NSArray<PRComment *> *comments;

@property (nonatomic, assign) DiffViewMode mode;

@end

@protocol PRDiffViewControllerDelegate <NSObject>

- (void)diffViewController:(PRDiffViewController *)vc
        queueReviewComment:(PendingPRComment *)comment;

- (void)diffViewController:(PRDiffViewController *)vc
          addReviewComment:(PendingPRComment *)comment;

- (void)diffViewController:(PRDiffViewController *)vc
         editReviewComment:(PRComment *)comment;

- (void)diffViewController:(PRDiffViewController *)vc
       deleteReviewComment:(PRComment *)comment;

- (void)diffViewController:(PRDiffViewController *)vc
        continueNavigation:(NSDictionary *)options;

@end

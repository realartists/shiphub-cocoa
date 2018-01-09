//
//  PRCommitController.h
//  ShipHub
//
//  Created by James Howard on 3/23/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PullRequest;
@class GitCommit;
@class GitDiff;

@protocol PRCommitControllerDelegate;

@interface PRCommitController : NSViewController

@property (nonatomic) PullRequest *pr;

@property (weak) id<PRCommitControllerDelegate> delegate;

- (void)highlightCommit:(GitCommit *)commit;
- (void)highlightSpanDiff:(GitDiff *)span;

@end

@protocol PRCommitControllerDelegate <NSObject>

- (void)commitControllerDidSelectSpanDiff:(PRCommitController *)cc;
- (void)commitControllerDidSelectSinceReviewSpanDiff:(PRCommitController *)cc;
- (void)commitControllerDidSelectSinceLastViewSpanDiff:(PRCommitController *)cc;
- (void)commitController:(PRCommitController *)cc didSelectCommit:(GitCommit *)commit;

@end

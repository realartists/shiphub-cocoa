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

@protocol PRCommitControllerDelegate;

@interface PRCommitController : NSViewController

@property (nonatomic) PullRequest *pr;

@property (weak) id<PRCommitControllerDelegate> delegate;

@end

@protocol PRCommitControllerDelegate <NSObject>

- (void)commitControllerDidSelectSpanDiff:(PRCommitController *)cc;
- (void)commitControllerDidSelectSinceReviewSpanDiff:(PRCommitController *)cc;
- (void)commitController:(PRCommitController *)cc didSelectCommit:(GitCommit *)commit;

@end

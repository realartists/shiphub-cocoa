//
//  PRReviewChangesViewController.h
//  ShipHub
//
//  Created by James Howard on 3/2/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PRReview;
@class PullRequest;

@protocol PRReviewChangesViewControllerDelegate;

@interface PRReviewChangesViewController : NSViewController

@property (weak) id<PRReviewChangesViewControllerDelegate> delegate;

@property (nonatomic) PullRequest *pr; // the state of the PR controls what types of reviews can be submitted.

@property (nonatomic) NSInteger numberOfPendingComments;

@end

@protocol PRReviewChangesViewControllerDelegate <NSObject>

- (void)reviewChangesViewController:(PRReviewChangesViewController *)vc submitReview:(PRReview *)review;

@end

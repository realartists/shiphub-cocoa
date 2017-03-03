//
//  PRReviewChangesViewController.h
//  ShipHub
//
//  Created by James Howard on 3/2/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PRReview;

@protocol PRReviewChangesViewControllerDelegate;

@interface PRReviewChangesViewController : NSViewController

@property (weak) id<PRReviewChangesViewControllerDelegate> delegate;

@property (nonatomic, getter=isMyPR) BOOL myPR; // you can only comment on your own PR, not accept or reject.

@end

@protocol PRReviewChangesViewControllerDelegate <NSObject>

- (void)reviewChangesViewController:(PRReviewChangesViewController *)vc submitReview:(PRReview *)review;

@end

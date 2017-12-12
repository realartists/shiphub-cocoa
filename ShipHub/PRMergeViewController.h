//
//  PRMergeViewController.h
//  ShipHub
//
//  Created by James Howard on 3/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PullRequest.h"
#import "Issue.h"

@protocol PRMergeViewControllerDelegate;

@interface PRMergeViewController : NSViewController

@property (nonatomic) Issue *issue;

@property (weak) id<PRMergeViewControllerDelegate> delegate;

@end

@protocol PRMergeViewControllerDelegate <NSObject>

- (void)mergeViewController:(PRMergeViewController *)vc didSubmitWithTitle:(NSString *)title message:(NSString *)message strategy:(PRMergeStrategy)strat;

@end

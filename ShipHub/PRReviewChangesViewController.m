//
//  PRReviewChangesViewController.m
//  ShipHub
//
//  Created by James Howard on 3/2/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRReviewChangesViewController.h"

#import "PRReview.h"

@interface PRReviewChangesViewController ()

@property IBOutlet NSTextField *titleLabel;
@property IBOutlet NSTextView *commentText;

@property IBOutlet NSButton *commentButton;
@property IBOutlet NSButton *approveButton;
@property IBOutlet NSButton *requestChangesButton;

@end

@implementation PRReviewChangesViewController

- (void)setMyPR:(BOOL)myPR {
    [self view];
    _myPR = myPR;
    
    _approveButton.enabled = !myPR;
    _approveButton.toolTip = myPR ? NSLocalizedString(@"GitHub does not allow you to approve your own pull request.", nil) : nil;
    _requestChangesButton.enabled = !myPR;
    _requestChangesButton.toolTip = myPR ? NSLocalizedString(@"GitHub does not allow you to request changes on your own pull request.", nil) : nil;
}

- (void)setNumberOfPendingComments:(NSInteger)numberOfPendingComments {
    [self view];
    
    _numberOfPendingComments = numberOfPendingComments;
    
    if (_numberOfPendingComments == 0) {
        _titleLabel.stringValue = NSLocalizedString(@"Add your review", nil);
    } else if (_numberOfPendingComments == 1) {
        _titleLabel.stringValue = NSLocalizedString(@"Submit 1 pending comment", nil);
    } else {
        _titleLabel.stringValue = [NSString localizedStringWithFormat:NSLocalizedString(@"Submit %td pending comments", nil), _numberOfPendingComments];
    }
}

- (IBAction)statusChanged:(NSButton *)sender {
    if ([sender state] != NSOnState) return;
    
    for (NSButton *b in @[_commentButton, _approveButton, _requestChangesButton]) {
        if (b != sender) {
            b.state = NSOffState;
        }
    }
}

- (IBAction)submit:(id)sender {
    PRReview *review = [PRReview new];
    if (_commentButton.state == NSOnState) {
        review.status = PRReviewStatusComment;
    } else if (_approveButton.state == NSOnState) {
        review.status = PRReviewStatusApprove;
    } else {
        NSAssert(_requestChangesButton.state == NSOnState, nil);
        review.status = PRReviewStatusRequestChanges;
    }
    review.body = _commentText.string;
    [self.delegate reviewChangesViewController:self submitReview:review];
}

@end

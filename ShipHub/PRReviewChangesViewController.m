//
//  PRReviewChangesViewController.m
//  ShipHub
//
//  Created by James Howard on 3/2/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRReviewChangesViewController.h"

#import "Account.h"
#import "Issue.h"
#import "PRReview.h"
#import "PullRequest.h"

@interface PRReviewChangesViewController ()

@property IBOutlet NSTextField *titleLabel;
@property IBOutlet NSTextView *commentText;

@property IBOutlet NSButton *commentButton;
@property IBOutlet NSButton *approveButton;
@property IBOutlet NSButton *requestChangesButton;

@end

@implementation PRReviewChangesViewController

- (void)setPr:(PullRequest *)pr {
    [self view];
    _pr = pr;
    
    BOOL myPR = [_pr.issue.originator.identifier isEqualToNumber:[[Account me] identifier]];
    BOOL merged = pr.merged;
    
    if (myPR) {
        _approveButton.enabled = NO;
        _approveButton.toolTip = NSLocalizedString(@"GitHub does not allow you to approve your own pull request.", nil);
        _requestChangesButton.enabled = NO;
        _requestChangesButton.toolTip = NSLocalizedString(@"GitHub does not allow you to request changes on your own pull request.", nil);
    } else if (merged) {
        _approveButton.enabled = NO;
        _requestChangesButton.enabled = NO;
        _approveButton.toolTip = _requestChangesButton.toolTip = NSLocalizedString(@"Pull request already merged.", nil);
    } else {
        _approveButton.enabled = YES;
        _requestChangesButton.enabled = YES;
        _approveButton.toolTip = nil;
        _requestChangesButton.toolTip = nil;
    }
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
        review.state = PRReviewStateComment;
    } else if (_approveButton.state == NSOnState) {
        review.state = PRReviewStateApprove;
    } else {
        NSAssert(_requestChangesButton.state == NSOnState, nil);
        review.state = PRReviewStateRequestChanges;
    }
    review.body = _commentText.string;
    [self.delegate reviewChangesViewController:self submitReview:review];
}

@end

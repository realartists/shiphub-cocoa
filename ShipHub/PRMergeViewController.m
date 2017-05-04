//
//  PRMergeViewController.m
//  ShipHub
//
//  Created by James Howard on 3/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRMergeViewController.h"

#import "Extras.h"
#import "Repo.h"

@interface PRMergeViewController ()

@property IBOutlet NSTextField *titleField;
@property IBOutlet NSTextView *messageView;
@property IBOutlet NSButton *mergeButton;
@property IBOutlet NSButton *squashButton;
@property IBOutlet NSButton *rebaseButton;

@end

@implementation PRMergeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _mergeButton.state = NSOnState;
}

- (void)setPr:(PullRequest *)pr {
    [self view];
    if (_pr != pr) {
        _pr = pr;
        _titleField.stringValue = [pr mergeTitle] ?: @"";
        _messageView.string = [pr mergeMessage] ?: @"";
    }
}

- (void)setIssue:(Issue *)i {
    [self view];
    if (_issue != i) {
        _issue = i;
        _titleField.stringValue = i != nil ? [NSString stringWithFormat:@"Merge pull request #%@ from %@/%@", i.number, i.repository.fullName, i.head[@"ref"]] : @"";
        _messageView.string = i.title ?: @"";
    }
}

- (IBAction)radioToggle:(id)sender {
    for (NSButton *b in @[_mergeButton, _squashButton, _rebaseButton]) {
        b.state = sender == b ? NSOnState : NSOffState;
    }
}

- (IBAction)help:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://help.github.com/articles/about-pull-request-merges/"]];
}

- (IBAction)submit:(id)sender {
    PRMergeStrategy strat;
    if (_mergeButton.state == NSOnState) {
        strat = PRMergeStrategyMerge;
    } else if (_squashButton.state == NSOnState) {
        strat = PRMergeStrategySquash;
    } else {
        strat = PRMergeStrategyRebase;
    }
    
    [self.delegate mergeViewController:self didSubmitWithTitle:[_titleField.stringValue trim] message:[_messageView.string trim] strategy:strat];
}

@end

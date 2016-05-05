//
//  ThreePaneController.m
//  ShipHub
//
//  Created by James Howard on 5/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "ThreePaneController.h"
#import "SearchResultsControllerPrivate.h"

#import "Extras.h"
#import "DataStore.h"
#import "Issue.h"
#import "Issue3PaneTableController.h"
#import "IssueViewController.h"

@interface ThreePaneController () <IssueTableControllerDelegate>

@property NSSplitViewController *splitController;
@property Issue3PaneTableController *tableController;
@property IssueViewController *issueController;

@property Issue *displayedIssue;

@end

@implementation ThreePaneController

- (void)loadView {
    self.table = _tableController = [Issue3PaneTableController new];
    _tableController.delegate = self;
    
    _issueController = [IssueViewController new];
    
    _splitController = [NSSplitViewController new];
    
    [_splitController addSplitViewItem:[NSSplitViewItem splitViewItemWithViewController:_tableController]];
    
    [_splitController addSplitViewItem:[NSSplitViewItem splitViewItemWithViewController:_issueController]];
    
    NSView *view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    [view setContentView:_splitController.view];
    self.view = view;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)issueTableController:(IssueTableController *)controller didChangeSelection:(NSArray<Issue *> *)selectedIssues {
    Issue *i = [selectedIssues firstObject];
    self.displayedIssue = i;
    
    DebugLog(@"%@", i.fullIdentifier);
    
    if (i) {
        [[DataStore activeStore] checkForIssueUpdates:i.fullIdentifier];
        [[DataStore activeStore] loadFullIssue:i.fullIdentifier completion:^(Issue *issue, NSError *error) {
            if ([self.displayedIssue.fullIdentifier isEqualToString:issue.fullIdentifier]) {
                _issueController.issue = issue;
            }
        }];
    } else {
        _issueController.issue = nil;
    }
}

@end

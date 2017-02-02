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
#import "RateDampener.h"

@interface ThreePaneController () <Issue3PaneTableControllerDelegate>

@property NSSplitViewController *splitController;
@property Issue3PaneTableController *tableController;
@property IssueViewController *issueController;

@property Issue *displayedIssue;
@property NSPredicate *displayedPredicate;
@property NSTimer *readTimer;

@property Issue *issueToRemoveOnSelectionChange;

@property RateDampener *checkForUpdatesDampener;

@end

@implementation ThreePaneController

- (id)init {
    if (self = [super init]) {
        _checkForUpdatesDampener = [RateDampener new];
    }
    return self;
}

- (void)loadView {
    self.table = _tableController = [Issue3PaneTableController new];
    _tableController.delegate = self;
    
    _issueController = [IssueViewController new];
    _issueController.columnBrowser = YES;
    
    _splitController = [NSSplitViewController new];
    
    NSSplitViewItem *tableItem = [NSSplitViewItem splitViewItemWithViewController:_tableController];
    NSSplitViewItem *issueItem = [NSSplitViewItem splitViewItemWithViewController:_issueController];
    
    if ([tableItem respondsToSelector:@selector(setMinimumThickness:)]) {
        tableItem.minimumThickness = 200.0;
        issueItem.minimumThickness = 440.0;
    }
    
    [_splitController addSplitViewItem:tableItem];
    [_splitController addSplitViewItem:issueItem];
    
    NSView *view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    [view setContentView:_splitController.view];
    self.view = view;
    
    _splitController.splitView.autosaveName = @"3Pane";
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)markAsRead:(NSTimer *)timer {
    if (self.displayedIssue == timer.userInfo) {
        [[DataStore activeStore] markIssueAsRead:self.displayedIssue.fullIdentifier];
    }
}

- (void)updateIssueViewController:(NSArray<Issue *> *)selectedIssues {
    Issue *i = [selectedIssues firstObject];
    
    self.displayedPredicate = self.predicate;
    
    if ([[_displayedIssue fullIdentifier] isEqualToString:[i fullIdentifier]]) {
        return;
    }
    
    if (_issueToRemoveOnSelectionChange && ![[i fullIdentifier] isEqualToString:_issueToRemoveOnSelectionChange.fullIdentifier]) {
        Issue *r = _issueToRemoveOnSelectionChange;
        _issueToRemoveOnSelectionChange = nil;
        [self.table removeSingleItem:r];
        [self updateTitle];
    }
    
    self.displayedIssue = i;
    
    if (_readTimer) {
        [_readTimer invalidate];
        _readTimer = nil;
    }
    
    DebugLog(@"%@", i.fullIdentifier);
    
    if (i) {
        [_checkForUpdatesDampener addBlock:^{
            [[DataStore activeStore] checkForIssueUpdates:i.fullIdentifier];
        }];
        [[DataStore activeStore] loadFullIssue:i.fullIdentifier completion:^(Issue *issue, NSError *error) {
            if ([self.displayedIssue.fullIdentifier isEqualToString:issue.fullIdentifier]) {
                _issueController.issue = issue;
                [_issueController noteCheckedForIssueUpdates];
            }
        }];
        
        _readTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 weakTarget:self selector:@selector(markAsRead:) userInfo:i repeats:NO];
    } else {
        _issueController.issue = nil;
    }
}

- (void)issueTableController:(IssueTableController *)controller didChangeSelection:(NSArray<Issue *> *)selectedIssues userInitiated:(BOOL)userInitiated {
    if (userInitiated || !self.displayedIssue || ![self.displayedPredicate isEqual:self.predicate]) {
        [self updateIssueViewController:selectedIssues];
    }
}

- (void)issueTableController:(Issue3PaneTableController *)table pageAuxiliaryViewBy:(NSInteger)direction {
    if (direction > 0) {
        [_issueController scrollPageDown:nil];
    } else {
        [_issueController scrollPageUp:nil];
    }
}

- (void)issueTableControllerFocusPreviousView:(Issue3PaneTableController *)table {
    [self.delegate resultsControllerFocusSidebar:self];
}

- (void)issueTableControllerFocusNextView:(Issue3PaneTableController *)table {
    [self.issueController takeFocus];
}

- (NSSize)preferredMinimumSize {
    NSSize s = NSMakeSize(0.0, 200.0);
    for (NSSplitViewItem *item in _splitController.splitViewItems) {
        s.width += item.minimumThickness;
        s.width += [NSScroller scrollerWidthForControlSize:NSRegularControlSize scrollerStyle:NSScrollerStyleLegacy];
    }
    return s;
}

- (NSArray *)willUpdateItems:(NSArray *)items {
    if (!self.upNextMode && self.displayedIssue && [self.displayedPredicate isEqual:self.predicate]) {
        Issue *i = self.displayedIssue;
        
        // Look and see if displayedIssue (i) is omitted from items.
        // If it is, we want to add it back in, but also update its display.
        // We'll remove it from view in the future when it is deselected.
        
        for (Issue *j in items) {
            if ([j.fullIdentifier isEqualToString:i.fullIdentifier]) {
                // Item existed. Clear state and bail out. Nothing special to do.
                _issueToRemoveOnSelectionChange = nil;
                return items;
            }
        }
        
        // If still here, we want to reload the item, and update the table with it.
        _issueToRemoveOnSelectionChange = i;
        
        DataStore *store = [DataStore activeStore];
        [store issuesMatchingPredicate:[store predicateForIssueIdentifiers:@[i.fullIdentifier]] completion:^(NSArray<Issue *> *issues, NSError *error) {
            if (_issueToRemoveOnSelectionChange == i) {
                Issue *j = [issues firstObject];
                _issueToRemoveOnSelectionChange = j;
                [self.table updateSingleItem:j];
            }
        }];
        
        return [items arrayByAddingObject:i];
    }
    return items;
}

- (void)didUpdateItems {
    if (!self.displayedIssue) {
        [self.table selectSomething];
    }
}

- (NSString *)autosaveName {
    return nil;
}

- (void)takeFocus {
    [self.view.window makeFirstResponder:self.table.view];
}

@end

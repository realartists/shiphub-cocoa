//
//  PRViewController.m
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRViewController.h"

#import "Extras.h"
#import "PullRequest.h"
#import "GitDiff.h"
#import "ProgressSheet.h"
#import "PRSidebarViewController.h"
#import "PRDiffViewController.h"

@interface PRViewController () <PRSidebarViewControllerDelegate>

@property NSSplitViewController *splitController;
@property NSSplitViewItem *sidebarItem;
@property PRSidebarViewController *sidebarController;
@property NSSplitViewItem *diffItem;
@property PRDiffViewController *diffController;

@end

@implementation PRViewController

- (void)loadView {
    NSView *view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    
    _sidebarController = [PRSidebarViewController new];
    _sidebarController.delegate = self;
    _diffController = [PRDiffViewController new];
    
    if ([[NSSplitViewItem class] respondsToSelector:@selector(contentListWithViewController:)]) {
        _sidebarItem = [NSSplitViewItem contentListWithViewController:_sidebarController];
    } else {
        _sidebarItem = [NSSplitViewItem splitViewItemWithViewController:_sidebarController];
        _sidebarItem.canCollapse = YES;
        _sidebarItem.holdingPriority = NSLayoutPriorityDefaultHigh;
    }
    
    _diffItem = [NSSplitViewItem splitViewItemWithViewController:_diffController];
    
    _splitController = [NSSplitViewController new];
    _splitController.splitViewItems = @[_sidebarItem, _diffItem];
    [view setContentView:_splitController.view];
    
    self.view = view;
}

- (void)loadForIssue:(Issue *)issue {
    self.pr = [[PullRequest alloc] initWithIssue:issue];
    
    ProgressSheet *sheet = [ProgressSheet new];
    sheet.message = NSLocalizedString(@"Loading Pull Request", nil);
    [sheet beginSheetInWindow:self.view.window];
    [self.pr checkout:^(NSError *error) {
        [sheet endSheet];
        
        if (error) {
            NSAlert *alert = [NSAlert new];
            alert.messageText = NSLocalizedString(@"Unable to load pull request", nil);
            alert.informativeText = [error localizedDescription];
            [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
        } else {
            _sidebarController.pr = self.pr;
        }
    }];
}

- (void)scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier {
    
}

- (void)prSidebar:(PRSidebarViewController *)sidebar didSelectGitDiffFile:(GitDiffFile *)file {
    _diffController.diffFile = file;
}

@end

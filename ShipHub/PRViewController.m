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
#import "DiffViewModeItem.h"

static NSString *const PRDiffViewModeKey = @"PRDiffViewMode";

@interface PRViewController () <PRSidebarViewControllerDelegate, NSToolbarDelegate> {
    NSToolbar *_toolbar;
    
    DiffViewModeItem *_diffViewModeItem;
}

@property NSSplitViewController *splitController;
@property NSSplitViewItem *sidebarItem;
@property PRSidebarViewController *sidebarController;
@property NSSplitViewItem *diffItem;
@property PRDiffViewController *diffController;

@end

@implementation PRViewController

- (NSToolbar *)toolbar {
    [self view];
    return _toolbar;
}

- (void)loadView {
    NSView *view = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    
    NSInteger defaultDiffMode = [[Defaults defaults] integerForKey:PRDiffViewModeKey fallback:DiffViewModeSplit];
    
    _sidebarController = [PRSidebarViewController new];
    _sidebarController.delegate = self;
    _diffController = [PRDiffViewController new];
    _diffController.mode = defaultDiffMode;
    
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
    
    _toolbar = [[NSToolbar alloc] initWithIdentifier:@"PRViewController"];
    _toolbar.delegate = self;
    
    DiffViewModeItem *diffItem = _diffViewModeItem = [[DiffViewModeItem alloc] initWithItemIdentifier:@"DiffViewMode"];
    diffItem.mode = defaultDiffMode;
    diffItem.target = self;
    diffItem.action = @selector(changeDiffViewMode:);
    
    self.view = view;
}

#pragma mark - Toolbar

- (IBAction)changeDiffViewMode:(id)sender {
    DiffViewMode mode = _diffViewModeItem.mode;
    [[Defaults defaults] setInteger:mode forKey:PRDiffViewModeKey];
    self.diffController.mode = _diffViewModeItem.mode;
}

- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:@"DiffViewMode"]) {
        return _diffViewModeItem;
    } else {
        return [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    }
}

- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[NSToolbarFlexibleSpaceItemIdentifier, _diffViewModeItem.itemIdentifier];
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

#pragma mark -

- (void)loadForIssue:(Issue *)issue {
    self.pr = [[PullRequest alloc] initWithIssue:issue];
    self.title = [NSString stringWithFormat:NSLocalizedString(@"Code Changes for %@ %@", nil), issue.fullIdentifier, issue.title];
    
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
    _diffViewModeItem.enabled = !(file.operation == DiffFileOperationAdded || file.operation == DiffFileOperationDeleted);
    [_diffController setPR:_pr diffFile:file comments:[_pr.prComments filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"path = %@", file.path]]];
}

@end

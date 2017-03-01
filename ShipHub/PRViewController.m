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
#import "PRComment.h"
#import "DiffViewModeItem.h"
#import "DataStore.h"

static NSString *const PRDiffViewModeKey = @"PRDiffViewMode";

@interface PRViewController () <PRSidebarViewControllerDelegate, PRDiffViewControllerDelegate, NSToolbarDelegate> {
    NSToolbar *_toolbar;
    
    DiffViewModeItem *_diffViewModeItem;
}

@property NSSplitViewController *splitController;
@property NSSplitViewItem *sidebarItem;
@property PRSidebarViewController *sidebarController;
@property NSSplitViewItem *diffItem;
@property PRDiffViewController *diffController;
@property NSMutableArray *pendingComments;
@property GitDiffFile *selectedFile;

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
    _diffController.delegate = self;
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
    
    self.pendingComments = [NSMutableArray new];
    
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

#pragma mark -

- (void)presentError:(NSError *)error withRetry:(dispatch_block_t)retry fail:(dispatch_block_t)fail {
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSCriticalAlertStyle;
    alert.messageText = NSLocalizedString(@"Unable to save changes", nil);
    alert.informativeText = [error localizedDescription] ?: @"";
    [alert addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Discard Changes", nil)];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            if (retry) retry();
        } else {
            if (fail) fail();
        }
    }];
}

- (NSArray *)allComments {
    return [_pr.prComments arrayByAddingObjectsFromArray:_pendingComments];
}

- (NSArray *)commentsForSelectedFile {
    GitDiffFile *file = _sidebarController.selectedFile;
    if (!file) return @[];
    GitDiff *diff = _sidebarController.activeDiff;
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"path = %@ AND position != nil AND commitId = %@", file.path, diff.headRev];
    NSArray *comments = [_pr.prComments filteredArrayUsingPredicate:filter];
    NSArray *pendingComments = [_pendingComments filteredArrayUsingPredicate:filter] ?: @[];
    return [comments arrayByAddingObjectsFromArray:pendingComments];
}

- (void)reloadComments {
    [_sidebarController setAllComments:[self allComments]];
    [_diffController setComments:[self commentsForSelectedFile]];
}

#pragma mark - PRSidebarViewControllerDelegate

- (void)prSidebar:(PRSidebarViewController *)sidebar didSelectGitDiffFile:(GitDiffFile *)file {
    GitDiff *diff = sidebar.activeDiff;
    _diffViewModeItem.enabled = !(file.operation == DiffFileOperationAdded || file.operation == DiffFileOperationDeleted);
    NSArray *comments = [self commentsForSelectedFile];
    [_diffController setPR:_pr diffFile:file diff:diff comments:comments inReview:_inReview];
}

#pragma mark - PRDiffViewControllerDelegate

- (void)diffViewController:(PRDiffViewController *)vc
        queueReviewComment:(PendingPRComment *)comment
{
    _inReview = YES;
    [_pendingComments addObject:comment];
    [self reloadComments];
}

- (void)diffViewController:(PRDiffViewController *)vc
          addReviewComment:(PendingPRComment *)comment
{
    [_pendingComments addObject:comment];
    [self reloadComments];
    [[DataStore activeStore] addSingleReviewComment:comment inIssue:_pr.issue.fullIdentifier completion:^(PRComment *roundtrip, NSError *error) {
        [_pendingComments removeObjectIdenticalTo:comment];
        if (error) {
            [self presentError:error withRetry:^{
                [self diffViewController:vc addReviewComment:comment];
            } fail:nil];
        } else {
            [_pr mergeComments:@[roundtrip]];
        }
        [self reloadComments];
    }];
}

- (void)diffViewController:(PRDiffViewController *)vc
         editReviewComment:(PRComment *)comment
{
    NSParameterAssert(comment.identifier);
    
    if ([comment isKindOfClass:[PendingPRComment class]]) {
        NSInteger existingIdx = [_pendingComments indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [[obj pendingId] isEqualToString:[(id)comment pendingId]];
        }];
        if (existingIdx != NSNotFound) {
            [_pendingComments replaceObjectAtIndex:existingIdx withObject:comment];
        }
        [self reloadComments];
    } else {
        NSInteger previousIdx = [_pr.prComments indexOfObjectPassingTest:^BOOL(PRComment * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [[obj identifier] isEqualToNumber:[comment identifier]];
        }];
        if (previousIdx != NSNotFound) {
            PRComment *previous = _pr.prComments[previousIdx];
            [_pr mergeComments:@[comment]];
            [self reloadComments];
            [[DataStore activeStore] editReviewComment:comment inIssue:_pr.issue.fullIdentifier completion:^(PRComment *roundtrip, NSError *error) {
                if (error) {
                    [_pr mergeComments:@[previous]];
                    [self presentError:error withRetry:^{
                        [self diffViewController:vc editReviewComment:comment];
                    } fail:^{
                        [self reloadComments];
                    }];
                } else {
                    [_pr mergeComments:@[roundtrip]];
                    [self reloadComments];
                }
            }];
        }
    }
}

- (void)diffViewController:(PRDiffViewController *)vc
       deleteReviewComment:(PRComment *)comment
{
    NSParameterAssert(comment.identifier);
    
    if ([comment isKindOfClass:[PendingPRComment class]]) {
        NSInteger existingIdx = [_pendingComments indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [[obj pendingId] isEqualToString:[(id)comment pendingId]];
        }];
        if (existingIdx != NSNotFound) {
            [_pendingComments removeObjectAtIndex:existingIdx];
        }
    } else {
        [_pr deleteComments:@[comment]];
        [self reloadComments];
        [[DataStore activeStore] deleteReviewComment:comment inIssue:_pr.issue.fullIdentifier completion:^(NSError *error) {
            if (error) {
                [_pr mergeComments:@[comment]];
                [self presentError:error withRetry:^{
                    [self diffViewController:vc editReviewComment:comment];
                } fail:^{
                    [self reloadComments];
                }];
            }
        }];
    }
}

@end

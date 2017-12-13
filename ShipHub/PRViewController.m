//
//  PRViewController.m
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRViewController.h"

#import "Account.h"
#import "AppAdapter.h"
#import "Auth.h"
#import "ButtonToolbarItem.h"
#import "CustomToolbarItem.h"
#import "Extras.h"
#import "PullRequest.h"
#import "GitDiff.h"
#import "GitFileSearch.h"
#import "IssueIdentifier.h"
#import "ProgressSheet.h"
#import "TrackingProgressSheet.h"
#import "PRAdapter.h"
#import "PRSidebarViewController.h"
#import "PRDiffViewController.h"
#import "PRComment.h"
#import "DiffViewModeItem.h"
#import "PRReview.h"
#import "PRReviewChangesViewController.h"
#import "PRNavigationToolbarItem.h"
#import "PRMergeViewController.h"
#import "PRPostMergeController.h"
#import "Reaction.h"
#import "SendErrorEmail.h"
#import "NSViewController+PresentSaveError.h"

static NSString *const PRDiffViewModeKey = @"PRDiffViewMode";
static NSString *const DiffViewModeID = @"DiffViewMode";
static NSString *const ReviewChangesID = @"ReviewChanges";
static NSString *const NavigationItemID = @"Navigation";
static NSString *const IssueItemID = @"Issue";
static NSString *const WorkingCopyItemID = @"WorkingCopy";
static NSString *const MergeItemID = @"Merge";
static NSString *const StatusItemID = @"Status";

static NSString *const TBNavigateItemID = @"TBNavigate";

@interface StatusToolbarItem : CustomToolbarItem

@property (nonatomic, copy) NSString *stringValue;
@property (nonatomic, copy) NSAttributedString *attributedStringValue;

@property (nonatomic) SEL clickAction;

@end

@interface PendingCommentKey : NSObject <NSCopying>

- (id)initWithComment:(PRComment *)prc;

@end

@interface PRViewController () <PRSidebarViewControllerDelegate, PRDiffViewControllerDelegate, PRReviewChangesViewControllerDelegate, PRMergeViewControllerDelegate, NSToolbarDelegate, NSTouchBarDelegate> {
    NSToolbar *_toolbar;
}

@property id<PRAdapter> adapter;

@property NSSplitViewController *splitController;
@property NSSplitViewItem *sidebarItem;
@property PRSidebarViewController *sidebarController;
@property NSSplitViewItem *diffItem;
@property PRDiffViewController *diffController;
@property PRReview *pendingReview;
@property NSMutableArray *pendingComments;
@property NSMutableSet<PendingCommentKey *> *pendingCommentGraveyard;

@property NSTimer *pendingReviewTimer;
@property BOOL savingPendingReview;

@property GitDiffFile *selectedFile;

@property DiffViewModeItem *diffViewModeItem;
@property ButtonToolbarItem *reviewChangesItem;
@property PRNavigationToolbarItem *navigationItem;
@property ButtonToolbarItem *issueItem;
@property ButtonToolbarItem *workingCopyItem;
@property ButtonToolbarItem *mergeItem;
@property StatusToolbarItem *statusItem;

@property (getter=isLoading) BOOL loading;
@property (getter=isOutOfDate) BOOL outOfDate; // YES if self.pr.head.sha != latest head sha available from GitHub

@property PRReviewChangesViewController *reviewChangesController;
@property NSPopover *reviewChangesPopover;

@property PRMergeViewController *mergeController;
@property NSPopover *mergePopover;

@property NSDictionary *nextScrollInfo;

@end

@implementation PRViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

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
    
    DiffViewModeItem *diffItem = _diffViewModeItem = [[DiffViewModeItem alloc] initWithItemIdentifier:DiffViewModeID];
    diffItem.toolTip = NSLocalizedString(@"Diff Mode", nil);
    diffItem.mode = defaultDiffMode;
    diffItem.target = self;
    diffItem.action = @selector(changeDiffViewMode:);
    
    ButtonToolbarItem *reviewChangesItem = _reviewChangesItem = [[ButtonToolbarItem alloc] initWithItemIdentifier:ReviewChangesID];
    reviewChangesItem.grayWhenDisabled = YES;
    reviewChangesItem.label = NSLocalizedString(@"Send Review", nil);
    reviewChangesItem.toolTip = NSLocalizedString(@"Send Review", nil);
    reviewChangesItem.buttonImage = [NSImage imageNamed:@"Review changes"];
    reviewChangesItem.buttonImage.template = YES;
    reviewChangesItem.target = self;
    reviewChangesItem.action = @selector(reviewChanges:);
    
    _navigationItem = [[PRNavigationToolbarItem alloc] initWithItemIdentifier:NavigationItemID];
    _navigationItem.toolTip = NSLocalizedString(@"Navigation", nil);
    _navigationItem.target = self;
    
    _issueItem = [[ButtonToolbarItem alloc] initWithItemIdentifier:IssueItemID];
    _issueItem.grayWhenDisabled = YES;
    _issueItem.label = _issueItem.toolTip = NSLocalizedString(@"Conversation", nil);
    _issueItem.buttonImage = [NSImage imageNamed:@"Open Issue"];
    _issueItem.buttonImage.template = YES;
    _issueItem.target = self;
    _issueItem.action = @selector(openIssue:);
    
    _workingCopyItem = [[ButtonToolbarItem alloc] initWithItemIdentifier:WorkingCopyItemID];
    _workingCopyItem.grayWhenDisabled = YES;
    _workingCopyItem.label = _workingCopyItem.toolTip = NSLocalizedString(@"Clone PR", nil);
    _workingCopyItem.buttonImage = [NSImage imageNamed:@"Terminal"];
    _workingCopyItem.buttonImage.template = YES;
    _workingCopyItem.target = self;
    _workingCopyItem.action = @selector(workingCopy:);
    
    _mergeItem = [[ButtonToolbarItem alloc] initWithItemIdentifier:MergeItemID];
    _mergeItem.grayWhenDisabled = YES;
    _mergeItem.label = _mergeItem.toolTip = NSLocalizedString(@"Merge", nil);
    _mergeItem.buttonImage = [NSImage imageNamed:@"Merge"];
    _mergeItem.buttonImage.template = YES;
    _mergeItem.target = self;
    _mergeItem.action = @selector(merge:);
    
    _statusItem = [[StatusToolbarItem alloc] initWithItemIdentifier:StatusItemID];
    _statusItem.target = self;
    
    _toolbar = [[NSToolbar alloc] initWithIdentifier:@"PRViewController"];
    _toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    _toolbar.delegate = self;
    
    self.view = view;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    [_diffController focus];
}

#pragma mark - Touch Bar

- (NSTouchBar *)makeTouchBar {
    NSTouchBar *tb = [NSTouchBar new];
    tb.customizationIdentifier = @"diff";
    tb.delegate = self;
    tb.defaultItemIdentifiers = @[TBNavigateItemID, NSTouchBarItemIdentifierOtherItemsProxy];
    
    return tb;
}

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if ([identifier isEqualToString:TBNavigateItemID]) {
        NSImage *downArrow = [NSImage imageNamed:@"DownArrow"];
        downArrow.template = YES;
        NSImage *upArrow = [NSImage imageNamed:@"UpArrow"];
        upArrow.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[upArrow, downArrow] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(tbNavigate:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    }
    return nil;
}

- (IBAction)tbNavigate:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self previousThing:sender]; break;
        case 1: [self nextThing:sender]; break;
    }
}

#pragma mark - Toolbar Actions

- (IBAction)changeDiffViewMode:(id)sender {
    DiffViewMode mode = _diffViewModeItem.mode;
    [[Defaults defaults] setInteger:mode forKey:PRDiffViewModeKey];
    self.diffController.mode = _diffViewModeItem.mode;
}

- (IBAction)reviewChanges:(id)sender {
    if (_reviewChangesPopover.shown) {
        [_reviewChangesPopover close];
        return;
    }
    
    if (!_reviewChangesController) {
        _reviewChangesController = [PRReviewChangesViewController new];
        _reviewChangesController.delegate = self;
    }
    
    _reviewChangesPopover = [[NSPopover alloc] init];
    _reviewChangesPopover.contentViewController = _reviewChangesController;
    _reviewChangesPopover.behavior = NSPopoverBehaviorSemitransient;
    
    _reviewChangesController.pr = _pr;
    _reviewChangesController.numberOfPendingComments = _pendingComments.count;
    
    [_reviewChangesPopover showRelativeToRect:_reviewChangesItem.view.bounds ofView:_reviewChangesItem.view preferredEdge:NSRectEdgeMinY];
}

- (IBAction)merge:(id)sender {
    if (_mergePopover.shown) {
        [_mergePopover close];
        return;
    }
    
    if (!_mergeController) {
        _mergeController = [PRMergeViewController new];
        _mergeController.delegate = self;
    }
    _mergeController.issue = _pr.issue;
    
    _mergePopover = [[NSPopover alloc] init];
    _mergePopover.contentViewController = _mergeController;
    _mergePopover.behavior = NSPopoverBehaviorSemitransient;
    
    [_mergePopover showRelativeToRect:_mergeItem.view.bounds ofView:_mergeItem.view preferredEdge:NSRectEdgeMinY];
}

static void SetWCVar(NSMutableString *shTemplate, NSString *var, NSString *val)
{
    NSString *replMe = [NSString stringWithFormat:@"%@=''", var];
    NSString *replWith = [NSString stringWithFormat:@"%@='%@'", var, val];
    
    [shTemplate replaceOccurrencesOfString:replMe withString:replWith options:0 range:NSMakeRange(0, shTemplate.length)];
}

- (IBAction)workingCopy:(id)sender {
    NSURL *shTemplateURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"clonepr" withExtension:@"sh"];
    NSMutableString *shTemplate = [[NSMutableString alloc] initWithContentsOfURL:shTemplateURL encoding:NSUTF8StringEncoding error:NULL];
    
    NSString *issueIdentifier = _pr.issue.fullIdentifier;
    NSString *repoName = [issueIdentifier issueRepoName];
    NSString *repoPath = _pr.bareRepoPath;
    NSString *remoteURL = [_pr.githubRemoteURL description];
    NSString *refName = [NSString stringWithFormat:@"pull/%@/head", [issueIdentifier issueNumber]];
    NSString *branchName = [NSString stringWithFormat:@"pull/%@", [issueIdentifier issueNumber]];
    NSString *baseRev = _pr.baseSha;
    NSString *headRev = _pr.headSha;
    
    SetWCVar(shTemplate, @"REPO_NAME", repoName);
    SetWCVar(shTemplate, @"REPO_PATH", repoPath);
    SetWCVar(shTemplate, @"REMOTE_URL", remoteURL);
    SetWCVar(shTemplate, @"REF_NAME", refName);
    SetWCVar(shTemplate, @"BRANCH_NAME", branchName);
    SetWCVar(shTemplate, @"BASE_REV", baseRev);
    SetWCVar(shTemplate, @"HEAD_REV", headRev);
    
    char buf[MAXPATHLEN];
    snprintf(buf, sizeof(buf), "%sclonepr.XXXXXX.sh", [NSTemporaryDirectory() UTF8String]);
    int fd = 0;
    if (-1 != (fd = mkstemps(buf, 3))) {
        NSString *shPath = [NSString stringWithUTF8String:buf];
        NSFileHandle *fh = [[NSFileHandle alloc] initWithFileDescriptor:fd];
        [fh writeData:[shTemplate dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
        
        NSURL *scriptURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"clonepr" withExtension:@"scpt"];
        
        NSDictionary *asError = nil;
        NSAppleScript *as = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&asError];
        
        NSError *scriptError = [NSAppleScript errorWithErrorDictionary:asError];
        
        if (scriptError) {
            [self presentError:scriptError];
            return;
        }
        
        NSArray *params = @[ shPath ];
        
        scriptError = [as callSubroutine:@"do_clone" withParams:params];
        
        if (scriptError) {
            [self presentError:scriptError];
        }
    } else {
        ErrLog(@"Unable to create temp file for clonepr.sh: %d %s", errno, strerror(errno));
    }
}

#pragma mark - Toolbar Delegate

- (nullable NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:DiffViewModeID]) {
        return _diffViewModeItem;
    } else if ([itemIdentifier isEqualToString:ReviewChangesID]) {
        return _reviewChangesItem;
    } else if ([itemIdentifier isEqualToString:NavigationItemID]) {
        return _navigationItem;
    } else if ([itemIdentifier isEqualToString:IssueItemID]) {
        return _issueItem;
    } else if ([itemIdentifier isEqualToString:WorkingCopyItemID]) {
        return _workingCopyItem;
    } else if ([itemIdentifier isEqualToString:MergeItemID]) {
        return _mergeItem;
    } else if ([itemIdentifier isEqualToString:StatusItemID]) {
        return _statusItem;
    } else {
        return [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
    }
}

- (NSArray<NSString *> *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    return @[IssueItemID,
             WorkingCopyItemID,
             MergeItemID,
             NSToolbarFlexibleSpaceItemIdentifier,
             StatusItemID,
             NSToolbarFlexibleSpaceItemIdentifier,
             NavigationItemID,
             DiffViewModeID,
             ReviewChangesID];
}

- (NSArray<NSString *> *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

#pragma mark - Status Item

- (void)updateStatusItem {
    NSMutableAttributedString *str = [NSMutableAttributedString new];
    NSFont *font1 = [NSFont systemFontOfSize:11.0];
    NSFont *font2 = [NSFont fontWithName:@"menlo" size:10.0];
    [str appendAttributes:@{ NSFontAttributeName : font1 } format:NSLocalizedString(@"PR #%@: %@ wants to merge ", nil), self.pr.issue.number, self.pr.issue.originator.login];
    [str appendAttributes:@{ NSFontAttributeName : font2 } format:@"%@", self.pr.headDescription];
    [str appendAttributes:@{ NSFontAttributeName : font1 } format:NSLocalizedString(@" into ", nil)];
    [str appendAttributes:@{ NSFontAttributeName : font2 } format:@"%@", self.pr.baseDescription];
    
    NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
    para.lineBreakMode = NSLineBreakByTruncatingHead;
    [str addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, str.length)];
    
    _statusItem.attributedStringValue = str;
}

#pragma mark - Navigation

- (IBAction)openIssue:(id)sender {
    [_adapter openConversationView];
}

- (void)scrollToLineInfo:(NSDictionary *)info {
    NSAssert([info[@"type"] isEqualToString:@"line"], nil);
    if (_loading) {
        _nextScrollInfo = info;
    } else if ([_sidebarController.selectedFile.path isEqualToString:info[@"path"]]) {
        [_diffController navigate:info];
    } else {
        _nextScrollInfo = info;
        [_sidebarController selectFileAtPath:info[@"path"]];
    }
}

- (IBAction)nextFile:(id)sender {
    [_sidebarController nextFile:self];
}

- (IBAction)previousFile:(id)sender {
    [_sidebarController previousFile:self];
}

- (IBAction)nextThing:(id)sender {
    [_diffController navigate:@{ @"direction" : @(1) }];
}

- (IBAction)previousThing:(id)sender {
    [_diffController navigate:@{ @"direction" : @(-1) }];
}

- (IBAction)nextChange:(id)sender {
    [_diffController navigate:@{ @"direction" : @(1),
                                 @"type" : @"hunk" }];
}
- (IBAction)previousChange:(id)sender {
    [_diffController navigate:@{ @"direction" : @(-1),
                                 @"type" : @"hunk" }];
}

- (IBAction)nextComment:(id)sender {
    [_diffController navigate:@{ @"direction" : @(1),
                                 @"type" : @"comment" }];
}

- (IBAction)previousComment:(id)sender {
    [_diffController navigate:@{ @"direction" : @(-1),
                                 @"type" : @"comment" }];
}

- (IBAction)filterInNavigator:(id)sender {
    [_sidebarController filterInNavigator:sender];
}

- (IBAction)findInFiles:(id)sender {
    [_sidebarController enterFindMode];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(nextFile:)) {
        return [_sidebarController canGoNextFile];
    } else if (menuItem.action == @selector(previousFile:)) {
        return [_sidebarController canGoPreviousFile];
    } else if (menuItem.action == @selector(merge:)) {
        return [_pr canMerge];
    } else if (menuItem.action == @selector(toggleSidebar:)) {
        if ([_splitController isSidebarCollapsed]) {
            menuItem.title = NSLocalizedString(@"Show Sidebar", nil);
        } else {
            menuItem.title = NSLocalizedString(@"Hide Sidebar", nil);
        }
        return YES;
    }
    return YES;
}

- (void)diffViewController:(PRDiffViewController *)vc continueNavigation:(NSDictionary *)options {
    NSString *type = options[@"type"] ?: @"";
    if ([options[@"direction"] integerValue] > 0) {
        if ([_sidebarController canGoNextFile]) {
            _nextScrollInfo = @{ @"type" : type,
                                 @"first" : @YES };
            
            if ([type isEqualToString:@"comment"]) {
                [_sidebarController nextCommentedFile:self];
            } else {
                [_sidebarController nextFile:self];
            }
        }
    } else {
        if ([_sidebarController canGoPreviousFile]) {
            _nextScrollInfo = @{ @"type" : type,
                                 @"last" : @YES };
            
            if ([type isEqualToString:@"comment"]) {
                [_sidebarController previousCommentedFile:self];
            } else {
                [_sidebarController previousFile:self];
            }
        }
    }
}

- (IBAction)performFindPanelAction:(id)sender {
    if (_sidebarController.inFindMode && [sender tag] == NSTextFinderActionNextMatch) {
        [_sidebarController nextFindResult:sender];
    } else if (_sidebarController.inFindMode && [sender tag] == NSTextFinderActionPreviousMatch) {
        [_sidebarController previousFindResult:sender];
    } else {
        [_diffController performTextFinderAction:sender];
    }
}

- (IBAction)performTextFinderAction:(nullable id)sender {
    [self performFindPanelAction:sender];
}

- (IBAction)toggleSidebar:(id)sender {
    NSSplitViewItem *item = [[_splitController splitViewItems] firstObject];
    item.animator.collapsed = !item.collapsed;
}

- (IBAction)showOmniSearch:(id)sender {
    [_sidebarController showOmniSearch:sender];
}

#pragma mark -

- (IBAction)copyIssueNumber:(id)sender {
    [NSString copyIssueIdentifiers:@[_pr.issue.fullIdentifier] toPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)copyIssueNumberWithTitle:(id)sender {
    [NSString copyIssueIdentifiers:@[_pr.issue.fullIdentifier] withTitles:@[_pr.issue.title] toPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)copyIssueGitHubURL:(id)sender {
    [_pr.issue.fullIdentifier copyIssueGitHubURLToPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)openDocumentInBrowser:(id)sender {
    NSURL *URL = [_pr gitHubFilesURL];
    if (URL) {
        [[NSWorkspace sharedWorkspace] openURL:URL];
    }
}

#pragma mark -

- (void)updateAdapter:(Issue *)issue {
    if (_adapter) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:PRAdapterDidUpdateIssueNotification object:_adapter];
    }
    
    _adapter = CreatePRAdapter(issue);
    
    _diffController.adapter = _adapter;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(issueDidUpdate:) name:PRAdapterDidUpdateIssueNotification object:_adapter];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pendingReviewDidDelete:) name:PRReviewDeletedExplicitlyNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pendingReviewDidEditComment:) name:PRReviewEditedCommentExplicitlyNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pendingReviewDidDeleteComment:) name:PRReviewDeletedCommentExplicitlyNotification object:nil];
}

- (void)loadForIssue:(Issue *)issue {
    [self updateAdapter:issue];
    
    _loading = YES;
    self.pr = [[PullRequest alloc] initWithIssue:issue];
    self.title = [NSString stringWithFormat:NSLocalizedString(@"Code Changes for %@ %@", nil), issue.fullIdentifier, issue.title];
    
    _statusItem.stringValue = [NSString stringWithFormat:NSLocalizedString(@"Loading changes for %@ %@ …", nil), issue.fullIdentifier, issue.title];
    
    self.pendingComments = [NSMutableArray new];
    self.pendingCommentGraveyard = nil;
    
    TrackingProgressSheet *sheet = [TrackingProgressSheet new];
    [sheet beginSheetInWindow:self.view.window];
    NSProgress *progress = [self.pr checkoutWithAdapter:_adapter completion:^(NSError *error) {
        [sheet endSheet];
        
        _loading = NO;
        _outOfDate = NO;
        
        NSDictionary *nextScroll = nil;
        if ([_nextScrollInfo[@"type"] isEqualToString:@"line"]) {
            nextScroll = _nextScrollInfo;
        }
        _nextScrollInfo = nil;
        
        if (self.pr.myLastPendingReview) {
            _inReview = YES;
            _pendingReview = self.pr.myLastPendingReview;
            [_pendingComments addObjectsFromArray:[_pendingReview.comments arrayByMappingObjects:^id(id obj) {
                return [[PendingPRComment alloc] initWithPRComment:obj];
            }]];
        }
        
        _mergeItem.enabled = self.pr.canMerge;
        
        if (error) {
            if ([error isCancelError]) {
                [[self.view window] close];
            } else {
                NSAlert *alert = [NSAlert new];
                alert.messageText = NSLocalizedString(@"Unable to load pull request", nil);
                alert.informativeText = [error localizedDescription];
                [alert addButtonWithTitle:NSLocalizedString(@"Close", nil)];
                [alert addButtonWithTitle:NSLocalizedString(@"Send Error Report", nil)];
                
                [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
                    if (returnCode == NSAlertSecondButtonReturn) {
                        [self sendErrorReport:error];
                    }
                    [[self.view window] close];
                }];
            }
        } else {
            [self updateStatusItem];
            _sidebarController.pr = self.pr;
        }
        
        [self reloadComments];
        
        if (nextScroll) {
            [self scrollToLineInfo:nextScroll];
        }
    }];
    dispatch_block_t prevCancellationHandler = progress.cancellationHandler;
    dispatch_block_t myCancellationHandler = ^{
        RunOnMain(^{
            [self.view.window close]; // realartists/shiphub-cocoa#672 Cancel right away when PR load is cancelled
        });
        if (prevCancellationHandler) {
            prevCancellationHandler();
        }
    };
    progress.cancellationHandler = myCancellationHandler;
    sheet.progress = progress;
}

- (void)scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier {
    
}

#pragma mark - Explicit PR Modifications from IssueViewController

- (void)pendingReviewDidDelete:(NSNotification *)note {
    NSString *issueIdentifier = note.userInfo[PRReviewDeletedInIssueIdentifierKey];
    if ([_pr.issue.fullIdentifier isEqualToString:issueIdentifier]) {
        _pendingReview = nil;
        _pendingComments = [NSMutableArray new];
        _pendingCommentGraveyard = nil;
        _inReview = NO;
        [self reloadComments];
    }
}

- (void)pendingReviewDidEditComment:(NSNotification *)note {
    PendingPRComment *updatedComment = [[PendingPRComment alloc] initWithPRComment:note.userInfo[PRReviewEditedCommentKey]];
    NSUInteger idx = [_pendingComments indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger x, BOOL *stop) {
        return [[obj assignedId] isEqual:[updatedComment assignedId]];
    }];
    if (idx == NSNotFound) return;
    PendingPRComment *currentComment = _pendingComments[idx];
    if ([currentComment.createdAt compare:updatedComment.createdAt] == NSOrderedAscending) {
        [_pendingComments replaceObjectAtIndex:idx withObject:updatedComment];
        [self reloadComments];
    }
}

- (void)pendingReviewDidDeleteComment:(NSNotification *)note {
    PendingPRComment *deletedComment = [[PendingPRComment alloc] initWithPRComment:note.userInfo[PRReviewDeletedCommentKey]];
    NSUInteger idx = [_pendingComments indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger x, BOOL *stop) {
        return [[obj assignedId] isEqual:[deletedComment assignedId]];
    }];
    if (idx == NSNotFound) return;
    [_pendingComments removeObjectAtIndex:idx];
    [self reloadComments];
}

#pragma mark - Updated Git Push Handling

- (void)issueDidUpdate:(NSNotification *)note {
    if (!_pr || _loading) return;
    [_adapter reloadFullIssueWithCompletion:^(Issue * issue, NSError *error) {
        if (issue) {
            [self mergeUpdatedIssue:issue];
        }
    }];
}

- (void)mergeUpdatedIssue:(Issue *)updatedIssue {
    if (![self.pr lightweightMergeUpdatedIssue:updatedIssue]) {
        _outOfDate = YES;
        _statusItem.clickAction = @selector(statusItemClicked:);
        
        NSMutableAttributedString *str = [NSMutableAttributedString new];
        
        NSFont *font = [NSFont systemFontOfSize:11.0];
        NSFont *bold = [NSFont boldSystemFontOfSize:11.0];
        NSFont *fixed = [NSFont fontWithName:@"menlo" size:10.0];
        
        [str appendAttributes:@{ NSFontAttributeName : font } format:NSLocalizedString(@"PR #%@: ", nil), self.pr.issue.fullIdentifier];
        
        [str appendAttributes:@{ NSFontAttributeName : bold } format:NSLocalizedString(@"New commits available on ", nil)];
        
        [str appendAttributes:@{ NSFontAttributeName : fixed } format:NSLocalizedString(@"%@ ", nil), self.pr.headDescription];
        
        [str appendAttributes:@{ NSFontAttributeName: bold, NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle) } format:NSLocalizedString(@"Click to Reload", nil)];
        
        NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
        para.lineBreakMode = NSLineBreakByTruncatingHead;
        [str addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, str.length)];
        
        _statusItem.attributedStringValue = str;
    }
    
    if (!_savingPendingReview) {
        uint64_t pendingReviewId = [_pendingReview.identifier unsignedLongLongValue];
        uint64_t nextPendingReviewId = [self.pr.myLastPendingReview.identifier unsignedLongLongValue];
        
        if (nextPendingReviewId > pendingReviewId) {
            DebugLog(@"Merging in updated pending review");
            _pendingReview = self.pr.myLastPendingReview;
            
            // merge in any new comments from pendingReview.
            // the tricky part is that their identifiers can't be used, since they rev
            // every time we save a review, so we have to merge them in by comparing the content of the comments
            
            NSMutableArray *allPending = [_pendingComments mutableCopy];
            for (PRComment *prc in _pendingReview.comments) {
                PendingPRComment *pprc = [[PendingPRComment alloc] initWithPRComment:prc];
                if (![self commentInGraveyard:pprc]) {
                    [allPending addObject:pprc];
                } else {
                    DebugLog(@"Ignoring comment in graveyard: %@", pprc);
                }
            }
            
            NSMutableArray *pendingComments = [NSMutableArray new];
            NSMutableSet *pendingCommentKeys = [NSMutableSet new];
            for (PendingPRComment *prc in allPending) {
                PendingCommentKey *key = [[PendingCommentKey alloc] initWithComment:prc];
                if (![pendingCommentKeys containsObject:key]) {
                    [pendingCommentKeys addObject:key];
                    [pendingComments addObject:prc];
                }
            }
            
            _inReview = _pendingReview != nil || pendingComments.count > 0;
            _pendingComments = pendingComments;
        }
    } else {
        DebugLog(@"Not merging in updated pending review, since we're saving it ourselves");
    }
    
    _mergeItem.enabled = self.pr.canMerge;
    
    [self reloadComments];
}

- (void)statusItemClicked:(id)sender {
    if (_outOfDate) {
        _outOfDate = NO;
        _statusItem.clickAction = nil;
        
        dispatch_block_t work = ^{
            [_adapter reloadFullIssueWithCompletion:^(Issue * issue, NSError *error) {
                if (issue) {
                    [self loadForIssue:issue];
                }
            }];
        };
        
        if (_pendingReviewTimer) {
            _statusItem.stringValue = [NSString stringWithFormat:NSLocalizedString(@"PR #%@: Saving pending review …", nil), self.pr.issue.fullIdentifier];
            [self savePendingReviewWithCompletion:work];
        } else {
            work();
        }
    }
}

#pragma mark - Error Handling

- (void)sendErrorReport:(NSError *)error {
    NSMutableString *errorReport = [NSMutableString new];
    
    NSString *appName = ([[NSBundle mainBundle] localizedInfoDictionary]?:[[NSBundle mainBundle] infoDictionary])[(__bridge id)kCFBundleNameKey];
    
    [errorReport appendFormat:@"%@ Pull Request Error Report\n", appName];
    [errorReport appendString:@"------------------------------\n\n"];
    [errorReport appendFormat:@"Date: %@\n", [NSDate date]];
    [errorReport appendFormat:@"GitHub User: %@\n", [[[SharedAppAdapter() auth] account] login]];
    NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
    [errorReport appendFormat:@"Ship Version: %@ (%@)\n", info[@"CFBundleShortVersionString"], info[@"CFBundleVersion"]];
    [errorReport appendFormat:@"System Version: %@\n\n", [[NSProcessInfo processInfo] operatingSystemVersionString]];
    
    [errorReport appendString:@"Error Details\n"];
    [errorReport appendString:@"-------------\n\n"];
    [errorReport appendFormat:@"%@\n\n", error];
    
    [errorReport appendString:@"Pull Request Data\n"];
    [errorReport appendString:@"-----------------\n\n"];
    [errorReport appendFormat:@"%@\n", [_pr debugDescription]];
    
    NSString *emailSubject = [NSString stringWithFormat:@"%@ Pull Request Error Report", appName];
    SendErrorEmail(emailSubject, errorReport);
}

- (BOOL)presentError:(NSError *)error {
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSCriticalAlertStyle;
    alert.messageText = NSLocalizedString(@"Error", nil);
    alert.informativeText = [error localizedDescription] ?: @"";
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Send Error Report", nil)];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            [self sendErrorReport:error];
        }
    }];
    
    return YES;
}

- (void)presentError:(NSError *)error withRetry:(dispatch_block_t)retry fail:(dispatch_block_t)fail {
    [self presentSaveError:error withRetry:retry fail:fail];
}

#pragma mark - Comments and Reviews

- (BOOL)commentInGraveyard:(PendingPRComment *)prc {
    NSParameterAssert(prc);
    
    PendingCommentKey *key = [[PendingCommentKey alloc] initWithComment:prc];
    return [_pendingCommentGraveyard containsObject:key];
}

- (void)removeCommentFromGraveyard:(PendingPRComment *)prc {
    NSParameterAssert(prc);
    
    PendingCommentKey *key = [[PendingCommentKey alloc] initWithComment:prc];
    [_pendingCommentGraveyard removeObject:key];
}

- (void)addCommentToGraveyard:(PendingPRComment *)prc {
    NSParameterAssert(prc);
    
    PendingCommentKey *key = [[PendingCommentKey alloc] initWithComment:prc];
    if (!_pendingCommentGraveyard) {
        _pendingCommentGraveyard = [NSMutableSet new];
    }
    [_pendingCommentGraveyard addObject:key];
}

- (NSArray *)mentionableAccounts {
    NSArray *accounts = [_adapter assigneesForRepo];
    NSMutableDictionary *lookup = [[NSDictionary lookupWithObjects:accounts keyPath:@"identifier"] mutableCopy];
    for (PRComment *prc in _pr.prComments) {
        [lookup setObject:prc.user forKey:prc.user.identifier];
    }
    [lookup removeObjectForKey:[[Account me] identifier]];
    return [lookup allValues];
}

- (NSArray *)allComments {
    return [_pr.prComments arrayByAddingObjectsFromArray:_pendingComments];
}

- (NSArray *)commentsForSelectedFile {
    GitDiffFile *file = _sidebarController.selectedFile;
    if (!file) return @[];
    NSString *headRev = _pr.spanDiff.headRev;
    NSPredicate *filter = [NSPredicate predicateWithFormat:@"path = %@ AND position != nil AND commitId = %@", file.path, headRev];
    NSArray *comments = [_pr.prComments filteredArrayUsingPredicate:filter];
    NSArray *pendingComments = [_pendingComments filteredArrayUsingPredicate:filter] ?: @[];
    return [comments arrayByAddingObjectsFromArray:pendingComments];
}

- (void)reloadComments {
    _reviewChangesItem.badgeString = _inReview && _pendingComments.count > 0 ? [NSString localizedStringWithFormat:@"%td", _pendingComments.count] : @"";
    [_sidebarController setAllComments:[self allComments]];
    [_diffController setComments:[self commentsForSelectedFile] inReview:_inReview];
}

- (void)scrollToComment:(PRComment *)comment {
    if ([comment.path isEqual:_diffController.diffFile.path]) {
        [_diffController scrollToComment:comment];
    } else {
        NSAssert(NO, @"not implemented yet");
    }
}

- (void)scheduleSavePendingReview {
    Trace();
    
    NSAssert([NSThread isMainThread], nil);
    
    // note that the timer will keep us alive so even if the window closes, we should be able to do the save anyway
    NSTimer *newTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(savePendingReviewTimerFired:) userInfo:nil repeats:NO];
    if (_pendingReviewTimer) {
        [_pendingReviewTimer invalidate];
    }
    _pendingReviewTimer = newTimer;
}

- (void)savePendingReviewWithCompletion:(dispatch_block_t)completion {
    _savingPendingReview = YES;
    
    if (_pendingReviewTimer) {
        [_pendingReviewTimer invalidate];
        _pendingReviewTimer = nil;
    }
    
    PRReview *review = [_pendingReview copy] ?: [PRReview new];
    review.commitId = [_pr headSha];
    review.comments = [_pendingComments copy];
    review.state = PRReviewStatePending;
    
    id<PRAdapter> adapter = _adapter;
    [adapter addReview:review completion:^(PRReview *roundtrip, NSError *error) {
        if (roundtrip) {
            _pendingReview = roundtrip;
            // try to update the pending identifiers for the comments to match roundtrip
            NSMutableDictionary<PendingCommentKey *, id> *pendingIDs = [NSMutableDictionary new];
            for (PRComment *prc in roundtrip.comments) {
                PendingCommentKey *key = [[PendingCommentKey alloc] initWithComment:prc];
                pendingIDs[key] = prc.identifier;
            }
            for (PendingPRComment *prc in _pendingComments) {
                PendingCommentKey *key = [[PendingCommentKey alloc] initWithComment:prc];
                NSNumber *assignedId = pendingIDs[key];
                if (assignedId) {
                    prc.assignedId = assignedId;
                }
            }
        }
        if (error) {
            ErrLog(@"Error saving pending review: %@", error);
        }
        
        _savingPendingReview = NO;
        
        if (completion) {
            completion();
        }
    }];
}

- (void)savePendingReviewTimerFired:(NSTimer *)timer {
    Trace();
    
    if (_savingPendingReview) {
        DebugLog(@"Queueing another pendingReviewTimer, because a save is already in progress");
        [self scheduleSavePendingReview];
    } else {
        [self savePendingReviewWithCompletion:nil];
    }
}

#pragma mark - PRSidebarViewControllerDelegate

- (void)prSidebar:(PRSidebarViewController *)sidebar didSelectGitDiffFile:(GitDiffFile *)file highlightingSearchResult:(GitFileSearchResult *)result
{
    GitDiff *diff = sidebar.activeDiff;
    _diffViewModeItem.enabled = !(file.operation == DiffFileOperationAdded || file.operation == DiffFileOperationDeleted);
    NSArray *comments = [self commentsForSelectedFile];
    NSDictionary *scrollInfo;
    if (result) {
        [_diffController hideFindController];
        NSString *regexText = result.search.query;
        if ((result.search.flags & GitFileSearchFlagRegex) == 0) {
            regexText = [NSRegularExpression escapedPatternForString:regexText];
        }
        scrollInfo = @{ @"type": @"line",
                        @"line" : @(result.matchedLineNumber),
                        @"highlight": @{ @"regex" : regexText,
                                         @"insensitive" : @(0 == (result.search.flags & GitFileSearchFlagCaseInsensitive)) }
                        };
    } else {
        scrollInfo = _nextScrollInfo ?: @{ @"first" : @YES };
    }
    _nextScrollInfo = nil;
    if (_diffController.diffFile != file) {
        [_diffController setPR:_pr diffFile:file diff:diff comments:comments mentionable:[self mentionableAccounts] inReview:_inReview scrollInfo:scrollInfo];
    } else {
        [_diffController navigate:scrollInfo];
    }
}

#pragma mark - PRReviewChangesViewControllerDelegate

- (void)reviewChangesViewController:(PRReviewChangesViewController *)vc submitReview:(PRReview *)review {
    [_reviewChangesPopover close];
    _reviewChangesPopover = nil;
    _reviewChangesController = nil;
    
    [_pendingReviewTimer invalidate];
    _pendingReviewTimer = nil;
    
    ProgressSheet *progress = [ProgressSheet new];
    progress.message = NSLocalizedString(@"Sending review", nil);
    [progress beginSheetInWindow:self.view.window];
    
    review.comments = _pendingComments;
    if (_pendingReview) {
        review.identifier = _pendingReview.identifier;
    }
    id<PRAdapter> adapter = _adapter;
    [adapter addReview:review completion:^(PRReview *roundtrip, NSError *error) {
        [progress endSheet];
        if (error) {
            [self presentError:error withRetry:^{
                [self reviewChangesViewController:nil submitReview:review];
            } fail:nil];
        } else {
            _pendingReview = nil;
            [_pr mergeComments:roundtrip.comments];
            [_pendingComments removeObjectsInArray:review.comments];
            [self reloadComments];
            
            [[self.view window] close];
        }
    }];
}

#pragma mark - PRMergeViewControllerDelegate

- (void)mergeViewController:(PRMergeViewController *)vc didSubmitWithTitle:(NSString *)title message:(NSString *)message strategy:(PRMergeStrategy)strat
{
    [_mergePopover close];
    _mergePopover = nil;
    _mergeController = nil;
    
    ProgressSheet *progress = [ProgressSheet new];
    progress.message = NSLocalizedString(@"Merging", nil);
    [progress beginSheetInWindow:self.view.window];
    
    [_pr performMergeWithMethod:strat title:title message:message completion:^(NSError *error) {
        [progress endSheet];
        if (error) {
            [self presentError:error withRetry:^{
                [self merge:nil];
            } fail:nil];
        } else {
            PRPostMergeController *postMerge = [PRPostMergeController new];
            postMerge.issue = _pr.issue;
            
            [postMerge beginSheetModalForWindow:self.view.window completion:^{
                [[self.view window] close];
            }];
        }
    }];
}

#pragma mark - PRDiffViewControllerDelegate

- (void)diffViewController:(PRDiffViewController *)vc
        queueReviewComment:(PendingPRComment *)comment
{
    _inReview = YES;
    [self removeCommentFromGraveyard:comment];
    [_pendingComments addObject:comment];
    [self reloadComments];
    [self scrollToComment:comment];
    [self scheduleSavePendingReview];
}

- (void)diffViewController:(PRDiffViewController *)vc
          addReviewComment:(PendingPRComment *)comment
{
    [self removeCommentFromGraveyard:comment];
    [_pendingComments addObject:comment];
    [self reloadComments];
    [self scrollToComment:comment];
    id<PRAdapter> adapter = _adapter;
    [adapter addSingleReviewComment:comment completion:^(PRComment *roundtrip, NSError *error) {
        if (error) {
            [self presentError:error withRetry:^{
                [_pendingComments removeObjectIdenticalTo:comment];
                [self diffViewController:vc addReviewComment:comment];
            } fail:^{
                [_pendingComments removeObjectIdenticalTo:comment];
                [self reloadComments];
            }];
        } else {
            [_pendingComments removeObjectIdenticalTo:comment];
            [_pr mergeComments:@[roundtrip]];
            [self reloadComments];
        }
    }];
}

- (void)diffViewController:(PRDiffViewController *)vc
         editReviewComment:(PRComment *)comment
{
    NSParameterAssert(comment);
    
    if ([comment isKindOfClass:[PendingPRComment class]]) {
        NSInteger existingIdx = [_pendingComments indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [[obj pendingId] isEqualToString:[(id)comment pendingId]];
        }];
        if (existingIdx != NSNotFound) {
            [self addCommentToGraveyard:_pendingComments[existingIdx]];
            [self removeCommentFromGraveyard:(PendingPRComment *)comment];
            [_pendingComments replaceObjectAtIndex:existingIdx withObject:comment];
            [self reloadComments];
            [self scheduleSavePendingReview];
        }
    } else {
        NSInteger previousIdx = [_pr.prComments indexOfObjectPassingTest:^BOOL(PRComment * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [[obj identifier] isEqualToNumber:[comment identifier]];
        }];
        if (previousIdx != NSNotFound) {
            PRComment *previous = _pr.prComments[previousIdx];
            [_pr mergeComments:@[comment]];
            [self reloadComments];
            id<PRAdapter> adapter = _adapter;
            [adapter editReviewComment:comment completion:^(PRComment *roundtrip, NSError *error) {
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
    if ([comment isKindOfClass:[PendingPRComment class]]) {
        NSInteger existingIdx = [_pendingComments indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [[obj pendingId] isEqualToString:[(id)comment pendingId]];
        }];
        if (existingIdx != NSNotFound) {
            [self addCommentToGraveyard:_pendingComments[existingIdx]];
            [_pendingComments removeObjectAtIndex:existingIdx];
            [self reloadComments];
            [self scheduleSavePendingReview];
        }
    } else {
        [_pr deleteComments:@[comment]];
        [self reloadComments];
        id<PRAdapter> adapter = _adapter;
        [adapter deleteReviewComment:comment completion:^(NSError *error) {
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

- (void)diffViewController:(PRDiffViewController *)vc
               addReaction:(NSString *)reaction
   toCommentWithIdentifier:(NSNumber *)commentIdentifier
{
    static int64_t reactionTemporaryId = 0;
    
    // eagerly add the reaction
    Reaction *r = [_adapter createReactionWithTemporaryId:@(--reactionTemporaryId) content:reaction createdAt:[NSDate date] user:[Account me]];
    
    PRComment *comment = [[self allComments] firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"identifier = %@", commentIdentifier]];
    
    if (!comment) {
        ErrLog(@"Cannot find comment with identifier %@", commentIdentifier);
        return;
    }
    
    comment.reactions = [comment.reactions arrayByAddingObject:r] ?: @[r];
    
    [self reloadComments];
    
    [_adapter postPRCommentReaction:r inPRComment:commentIdentifier completion:^(Reaction *roundtrip, NSError *error) {
        
        comment.reactions = [comment.reactions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != %@", r]];
        if (roundtrip) {
            comment.reactions = [comment.reactions arrayByAddingObject:roundtrip];
        }
        
        [self reloadComments];
        
        if (error) {
            [self presentError:error withRetry:^{
                [self diffViewController:vc addReaction:reaction toCommentWithIdentifier:commentIdentifier];
            } fail:nil];
        }
    }];
}

- (void)diffViewController:(PRDiffViewController *)vc
deleteReactionWithIdentifier:(NSNumber *)reactionIdentifier
 fromCommentWithIdentifier:(NSNumber *)commentIdentifier
{
    PRComment *comment = [[self allComments] firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"identifier = %@", commentIdentifier]];
    Reaction *r = [comment.reactions firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"identifier = %@", reactionIdentifier]];
    
    if (!r) return;
    
    // eagerly delete the reaction
    comment.reactions = [comment.reactions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != %@", r]];
    
    [self reloadComments];
    
    [_adapter deleteReaction:reactionIdentifier completion:^(NSError *error) {
        if (error) {
            comment.reactions = [comment.reactions arrayByAddingObject:r];
            [self reloadComments];
            [self presentError:error withRetry:^{
                [self diffViewController:vc deleteReactionWithIdentifier:reactionIdentifier fromCommentWithIdentifier:commentIdentifier];
            } fail:nil];
        }
    }];
}


@end


@interface StatusTextField : NSTextField

@property (nonatomic) SEL clickAction;

@end

@interface StatusTextFieldCell : NSTextFieldCell

@end

@interface StatusToolbarItem ()

@property StatusTextField *labelView;

@end

@implementation StatusToolbarItem

- (void)configureView {
    _labelView = [[StatusTextField alloc] initWithFrame:CGRectMake(0, 0, 700.0, 28.0)];
    _labelView.editable = NO;
    _labelView.selectable = NO;
    _labelView.font = [NSFont systemFontOfSize:11.0];
    _labelView.autoresizingMask = NSViewWidthSizable;
    _labelView.lineBreakMode = NSLineBreakByTruncatingHead;
    self.view = _labelView;
    self.minSize = CGSizeMake(200.0, 28.0);
    self.maxSize = CGSizeMake(700.0, 28.0);
}

- (void)setStringValue:(NSString *)stringValue {
    _labelView.stringValue = stringValue ?: @"";
    _labelView.toolTip = stringValue;
}

- (NSString *)stringValue {
    return _labelView.stringValue;
}

- (void)setAttributedStringValue:(NSAttributedString *)attributedStringValue {
    _labelView.attributedStringValue = attributedStringValue;
    _labelView.toolTip = attributedStringValue.string;
}

- (NSAttributedString *)attributedStringValue {
    return _labelView.attributedStringValue;
}

- (void)setClickAction:(SEL)clickAction {
    _labelView.clickAction = clickAction;
}

@end

@implementation StatusTextField

+ (Class)cellClass { return [StatusTextFieldCell class]; }

- (void)performClick:(id)sender {
    [self onClick];
}

- (void)mouseDown:(NSEvent *)event {
    [self onClick];
}

- (void)onClick {
    [self sendAction:self.clickAction to:self.target];
}

- (void)setClickAction:(SEL)clickAction {
    _clickAction = clickAction;
    [self.window invalidateCursorRectsForView:self];
}

- (void)resetCursorRects {
    [super resetCursorRects];
    if (_clickAction) {
        [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
    }
}

@end

@implementation StatusTextFieldCell

// https://red-sweater.com/blog/148/what-a-difference-a-cell-makes
- (NSRect)drawingRectForBounds:(NSRect)rect {
    // Get the parent's idea of where we should draw
    NSRect newRect = [super drawingRectForBounds:rect];
    
    // Get our ideal size for current text
    NSSize textSize = [self cellSizeForBounds:rect];
    
    // Center that in the proposed rect
    float heightDelta = newRect.size.height - textSize.height;
    if (heightDelta > 0)
    {
        newRect.size.height -= heightDelta;
        newRect.origin.y += (heightDelta / 2);
    }
    
    // Add a little left and right padding
    newRect = CGRectInset(newRect, 8.0, 0.0);
    
    // fudge down a little bit (no idea why)
    newRect.origin.y += 1.0;
    
    return newRect;
}

@end

@implementation PendingCommentKey {
    NSString *_body;
    NSString *_path;
    NSNumber *_position;
}

- (id)initWithComment:(PRComment *)prc {
    if (self = [super init]) {
        _body = prc.body;
        _path = prc.path;
        _position = prc.position;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (BOOL)isEqual:(id)object {
    if ([object isKindOfClass:[PendingCommentKey class]]) {
        PendingCommentKey *b = (id)object;
        return
            [NSObject object:_position isEqual:b->_position] &&
            [NSObject object:_path isEqual:b->_path] &&
            [NSObject object:_body isEqual:b->_body];
    }
    return NO;
}

- (NSUInteger)hash {
    NSUInteger hash = 1;
    hash = hash * 33 + [_body hash];
    hash = hash * 33 + [_path hash];
    hash = hash * 33 + [_position hash];
    return hash;
}

@end

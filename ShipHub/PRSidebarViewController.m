//
//  PRSidebarViewController.m
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRSidebarViewController.h"

#import "Extras.h"
#import "Issue.h"
#import "Repo.h"
#import "PullRequest.h"
#import "PRComment.h"
#import "GitCommit.h"
#import "GitDiff.h"
#import "GitFileSearch.h"
#import "PRCommitController.h"
#import "NSImage+Icons.h"

@interface PRSidebarCellView : NSTableCellView

@property IBOutlet NSTextField *changeLabel;
@property IBOutlet NSLayoutConstraint *commentWidthConstraint;

@property (nonatomic, assign) BOOL hasComments;
@property (nonatomic, copy) NSString *changeType;
@property (nonatomic, copy) NSString *filename;

@end

@interface PRSidebarFindFileResultCellView : NSTableCellView

@property (nonatomic, strong) GitFileSearchResult *result;

- (CGFloat)heightForWidth:(CGFloat)width;

@end

@interface PRSidebarRowView : NSTableRowView

@end

@interface PRSidebarOutlineView : NSOutlineView

@end

typedef NS_ENUM(NSInteger, FindMenuTags) {
    FindMenuTagCaseSensitive = 1,
    FindMenuTagRegEx = 2,
    FindMenuTagChangedLinesOnly = 3
};

@interface PRSidebarViewController () <NSOutlineViewDelegate, NSOutlineViewDataSource, NSTextFieldDelegate, PRCommitControllerDelegate>

@property IBOutlet PRSidebarOutlineView *outline;

@property IBOutlet NSTextField *findField;
@property IBOutlet NSButton *findMenuButton;
@property IBOutlet NSButton *findCancelButton;
@property IBOutlet NSMenu *findMenu;
@property NSMutableArray *findResults;
@property NSArray *filteredFindResults;
@property NSProgress *findProgress;
@property PRSidebarFindFileResultCellView *findResultSizingView;
@property NSTimer *findResultHeightCalculationTimer;

@property IBOutlet NSSearchField *filterField;
@property IBOutlet NSButton *commentFilterButton;

@property IBOutlet NSButton *showCommitsButton;
@property IBOutlet NSTextField *commitLabel;

@property NSPopover *commitPopover;
@property PRCommitController *commitController;

@property GitDiff *filteredDiff;
@property NSArray *inorderFiles;
@property NSSet *commentedPaths;

@end

@implementation PRSidebarViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _findField.delegate = self;
    [[_outline enclosingScrollView] setScrollerStyle:NSScrollerStyleOverlay];
    _showCommitsButton.enabled = NO;
    _commitLabel.stringValue = @"";
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameDidChange:) name:NSViewFrameDidChangeNotification object:self.view];
}

- (void)frameDidChange:(NSNotification *)note {
    if (_inFindMode) {
        if (!_findResultHeightCalculationTimer) {
            _findResultHeightCalculationTimer = [NSTimer scheduledTimerWithTimeInterval:0.1666*3.0 target:self selector:@selector(noteHeightsChanged) userInfo:nil repeats:NO];
        }
    }
}

- (void)noteHeightsChanged {
    _findResultHeightCalculationTimer = nil;
    [_outline noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _outline.numberOfRows)]];
}

- (void)reloadData {
    GitDiffFile *file = [_outline selectedItem];
    [_outline reloadData];
    [self selectFile:file];
}

- (void)setPr:(PullRequest *)pr {
    NSAssert(pr.spanDiff != nil, nil);
    
    _pr = pr;
    _showCommitsButton.enabled = pr != nil;
    _commitController.pr = pr;
    _activeCommit = nil;
    self.activeDiff = pr.spanDiff;
}

- (void)setAllComments:(NSArray<PRComment *> *)allComments {
    NSArray *relevantComments = [allComments filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"commitId == %@ AND position != nil", _activeDiff.headRev]];
    _commentedPaths = [NSSet setWithArray:[relevantComments arrayByMappingObjects:^id(PRComment * obj) {
        return [obj path];
    }]];
    _allComments = allComments;
    [self reloadData];
}

- (void)updateCommitLabel {
    if (self.activeDiff == _pr.spanDiff) {
        _commitLabel.stringValue = [NSString localizedStringWithFormat:NSLocalizedString(@"All Commits (%tu)", nil), _pr.commits.count];
    } else if (self.activeDiff == _pr.spanDiffSinceMyLastReview) {
        _commitLabel.stringValue = NSLocalizedString(@"Changes since your last review", nil);
    } else if (self.activeDiff == _pr.spanDiffSinceMyLastView) {
        _commitLabel.stringValue = NSLocalizedString(@"Changes since you last viewed", nil);
    } else if (self.activeCommit) {
        _commitLabel.stringValue = [_activeCommit.message trim];
    } else {
        _commitLabel.stringValue = @"";
    }
}

- (IBAction)showCommits:(id)sender {
    if (_commitPopover.shown) {
        [_commitPopover close];
        return;
    }
    
    if (!_commitController) {
        _commitController = [PRCommitController new];
        _commitController.delegate = self;
    }
    _commitController.pr = _pr;
    
    if (!_commitPopover) {
        _commitPopover = [NSPopover new];
        _commitPopover.contentViewController = _commitController;
        _commitPopover.behavior = NSPopoverBehaviorSemitransient;
    }
    
    [_commitPopover showRelativeToRect:_showCommitsButton.bounds ofView:_showCommitsButton preferredEdge:NSRectEdgeMinY];
}

- (void)commitControllerDidSelectSpanDiff:(PRCommitController *)cc {
    _activeCommit = nil;
    self.activeDiff = _pr.spanDiff;
    [_commitPopover close];
}

- (void)commitControllerDidSelectSinceReviewSpanDiff:(PRCommitController *)cc {
    _activeCommit = nil;
    self.activeDiff = _pr.spanDiffSinceMyLastReview;
    [_commitPopover close];
}

- (void)commitControllerDidSelectSinceLastViewSpanDiff:(PRCommitController *)cc {
    _activeCommit = nil;
    self.activeDiff = _pr.spanDiffSinceMyLastView;
    [_commitPopover close];
}

- (void)commitController:(PRCommitController *)cc didSelectCommit:(GitCommit *)commit {
    [commit loadDiff:^(GitDiff *diff, NSError *err) {
        if (!err) {
            _activeCommit = commit;
            self.activeDiff = diff;
        } else {
            [self presentError:err];
        }
    }];
    [_commitPopover close];
}

static void traverseFiles(GitFileTree *tree, NSMutableArray *files) {
    if (!tree) return;
    
    for (id item in tree.children) {
        if ([item isKindOfClass:[GitDiffFile class]]) {
            [files addObject:item];
        } else {
            traverseFiles(item, files);
        }
    }
}

- (void)buildInorderFiles {
    // create inorderFiles, a traversal of
    // the tree that's the same order as the fully
    // expanded outline view
    NSMutableArray *files = [NSMutableArray new];
    traverseFiles(_filteredDiff.fileTree, files);
    _inorderFiles = files;
}

- (void)setActiveDiff:(GitDiff *)diff {
    if (_activeDiff != diff) {
        _activeDiff = diff;
        _filteredDiff = diff;
        
        [_filterField setStringValue:@""];
        _commentFilterButton.state = NSOffState;
        
        [self updateCommitLabel];
        
        [self buildInorderFiles];
        
        [_outline reloadData];
        [_outline expandItem:nil expandChildren:YES];
        [self selectFirstItem];
    }
}

- (void)updateFilteredDiff {
    NSString *pathFilter = [_filterField.stringValue trim];
    BOOL mustBeCommented = _commentFilterButton.state == NSOnState;
    _filteredDiff = [_activeDiff copyByFilteringFilesWithPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        
        GitDiffFile *file = evaluatedObject;
        if (mustBeCommented && ![_commentedPaths containsObject:file.path]) {
            return NO;
        }
        
        if ([pathFilter length] && ![file.path localizedStandardContainsString:pathFilter]) {
            return NO;
        }
        
        return YES;
    }]];
    
    [self buildInorderFiles];
    
    if (_inFindMode) {
        [self updateFilteredFindResults];
    }
    
    [self buildInorderFiles];
    [self reloadData];
    [_outline expandItem:nil expandChildren:YES];
    if (![_outline selectedItem]) {
        [self selectFirstItem];
    }
}

- (void)resetAllFilters {
    [self cancelFindMode];
    BOOL hadFilter = NO;
    if (_filterField.stringValue.length) {
        _filterField.stringValue = @"";
        hadFilter = YES;
    }
    if (_commentFilterButton.state != NSOffState) {
        _commentFilterButton.state = NSOffState;
        hadFilter = YES;
    }
    
    if (hadFilter) {
        [self updateFilteredDiff];
    }
}

- (void)selectFirstItem {
    if (_inFindMode) {
        [_outline expandItem:nil expandChildren:YES];
        if ([_filteredFindResults count]) {
            [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:1] byExtendingSelection:NO];
            [_outline scrollRowToVisible:1];
        }
    } else {
        GitDiffFile *first = [_inorderFiles firstObject];
        if (first) {
            [self selectFile:first];
        }
    }
}

- (void)selectFile:(GitDiffFile *)item {
    if (_inFindMode) {
        NSInteger i = [_filteredFindResults indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            GitFileSearchResult *result = [obj firstObject];
            return result.file == item;
        }];
        if (i != NSNotFound) {
            NSInteger row = [_outline rowForItem:_filteredFindResults[i]];
            if (row != -1) {
                [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
                [_outline scrollRowToVisible:row];
            }
        }
    } else {
        GitFileTree *tree = item.parentTree;
        NSMutableArray *path = [NSMutableArray new];
        while (tree) {
            [path addObject:tree];
            tree = tree.parentTree;
        }
        for (tree in path.reverseObjectEnumerator) {
            [_outline expandItem:tree];
        }
        NSInteger row = [_outline rowForItem:item];
        if (row != -1) {
            [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [_outline scrollRowToVisible:row];
        }
    }
}

- (BOOL)canGoNextFile {
    id item = [_outline selectedItem];
    if (_inFindMode) {
        if ([item isKindOfClass:[GitFileSearchResult class]]) {
            item = [_outline parentForItem:item];
        }
        if (item) {
            NSInteger idx = [_filteredFindResults indexOfObjectIdenticalTo:item];
            return (idx+1 < _filteredFindResults.count);
        }
    } else {
        if (item) {
            NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
            return (idx+1 < _inorderFiles.count);
        }
    }
    return NO;
}

- (BOOL)canGoPreviousFile {
    id item = [_outline selectedItem];
    if (_inFindMode) {
        if ([item isKindOfClass:[GitFileSearchResult class]]) {
            item = [_outline parentForItem:item];
        }
        if (item) {
            NSInteger idx = [_filteredFindResults indexOfObjectIdenticalTo:item];
            return idx > 0;
        }
    } else {
        if (item) {
            NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
            return idx > 0;
        }
    }
    return NO;
}

- (IBAction)nextFile:(id)sender {
    id item = [_outline selectedItem];
    if (_inFindMode) {
        if ([item isKindOfClass:[GitFileSearchResult class]]) {
            item = [_outline parentForItem:item];
        }
        if (item) {
            NSInteger idx = [_filteredFindResults indexOfObjectIdenticalTo:item];
            if (idx+1 < _filteredFindResults.count) {
                [self selectFile:[[_filteredFindResults[idx+1] firstObject] file]];
            }
        }
    } else {
        if (item) {
            NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
            if (idx+1 < _inorderFiles.count) {
                [self selectFile:_inorderFiles[idx+1]];
            }
        }
    }
}

- (IBAction)previousFile:(id)sender {
    id item = [_outline selectedItem];
    if (_inFindMode) {
        if ([item isKindOfClass:[GitFileSearchResult class]]) {
            item = [_outline parentForItem:item];
        }
        if (item) {
            NSInteger idx = [_filteredFindResults indexOfObjectIdenticalTo:item];
            if (idx > 0) {
                [self selectFile:[[_filteredFindResults[idx-1] firstObject] file]];
            }
        }
    } else {
        if (item) {
            NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
            if (idx > 0) {
                [self selectFile:_inorderFiles[idx-1]];
            }
        }
    }
}

- (IBAction)nextCommentedFile:(id)sender {
    id item = [_outline selectedItem];
    if (_inFindMode) {
        if ([item isKindOfClass:[GitFileSearchResult class]]) {
            item = [_outline parentForItem:item];
        }
        if (item) {
            NSInteger idx = [_filteredFindResults indexOfObjectIdenticalTo:item];
            idx++;
            
            while (idx < _filteredFindResults.count && ![_commentedPaths containsObject:[[[_filteredFindResults[idx] firstObject] file] path]])
                idx++;
            if (idx < _filteredFindResults.count) {
                [self selectFile:[[_filteredFindResults[idx] firstObject] file]];
            }
        }
    } else {
        if (item) {
            NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
            idx++;
            while (idx < _inorderFiles.count && ![_commentedPaths containsObject:[_inorderFiles[idx] path]])
                idx++;
            if (idx < _inorderFiles.count) {
                [self selectFile:_inorderFiles[idx]];
            }
        }
    }
}

- (IBAction)previousCommentedFile:(id)sender {
    id item = [_outline selectedItem];
    if (_inFindMode) {
        if ([item isKindOfClass:[GitFileSearchResult class]]) {
            item = [_outline parentForItem:item];
        }
        if (item) {
            NSInteger idx = [_filteredFindResults indexOfObjectIdenticalTo:item];
            idx--;
            
            while (idx >= 0 && ![_commentedPaths containsObject:[[[_filteredFindResults[idx] firstObject] file] path]])
                idx--;
            if (idx >= 0) {
                [self selectFile:[[_filteredFindResults[idx] firstObject] file]];
            }
        }
    } else {
        if (item) {
            NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
            idx--;
            while (idx >= 0 && ![_commentedPaths containsObject:[_inorderFiles[idx] path]])
                idx--;
            if (idx >= 0) {
                [self selectFile:_inorderFiles[idx]];
            }
        }
    }
}

- (BOOL)canGoNextFindResult {
    if (!_inFindMode) return NO;
    
    id item = [_outline selectedItem];
    if ([item isKindOfClass:[NSArray class]]) {
        return YES;
    } else {
        NSArray *parent = [_outline parentForItem:item];
        NSInteger parentIdx = [_outline childIndexForItem:parent];
        NSInteger idx = [parent indexOfObjectIdenticalTo:item];
        return idx+1 < parent.count || parentIdx+1 < _filteredFindResults.count;
    }
}

- (BOOL)canGoPreviousFindResult {
    if (!_inFindMode) return NO;
    
    id item = [_outline selectedItem];
    if ([item isKindOfClass:[NSArray class]]) {
        NSInteger idx = [_outline childIndexForItem:item];
        return idx > 0;
    } else {
        NSArray *parent = [_outline parentForItem:item];
        NSInteger parentIdx = [_outline childIndexForItem:parent];
        NSInteger idx = [parent indexOfObjectIdenticalTo:item];
        return idx > 0 || parentIdx > 0;
    }
}

- (void)_nextFindResult:(id)item {
    if (!_inFindMode || !item) return;
    
    if ([item isKindOfClass:[NSArray class]]) {
        [_outline expandItem:item expandChildren:YES];
        NSInteger row = [_outline rowForItem:[item firstObject]];
        if (row != -1) {
            [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [_outline scrollRowToVisible:row];
        }
    } else {
        NSArray *parent = [_outline parentForItem:item];
        NSInteger parentIdx = [_outline childIndexForItem:parent];
        NSInteger idx = [parent indexOfObjectIdenticalTo:item];
        if (idx + 1 < parent.count) {
            NSInteger row = [_outline rowForItem:parent[idx+1]];
            [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [_outline scrollRowToVisible:row];
        } else if (parentIdx+1 < _filteredFindResults.count) {
            [self _nextFindResult:_filteredFindResults[parentIdx+1]];
        }
    }
}

- (void)_previousFindResult:(id)item {
    if (!_inFindMode || !item) return;
    
    if ([item isKindOfClass:[NSArray class]]) {
        NSInteger idx = [_outline childIndexForItem:item];
        if (idx > 0) {
            idx--;
            item = [_outline child:idx ofItem:nil];
        }
        [_outline expandItem:item expandChildren:YES];
        NSInteger row = [_outline rowForItem:[item lastObject]];
        if (row != -1) {
            [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [_outline scrollRowToVisible:row];
        }
    } else {
        NSArray *parent = [_outline parentForItem:item];
        NSInteger parentIdx = [_outline childIndexForItem:parent];
        NSInteger idx = [parent indexOfObjectIdenticalTo:item];
        if (idx > 0) {
            NSInteger row = [_outline rowForItem:parent[idx-1]];
            [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
            [_outline scrollRowToVisible:row];
        } else if (parentIdx > 0) {
            [self _previousFindResult:_filteredFindResults[parentIdx]];
        }
    }
}

- (IBAction)nextFindResult:(id)sender {
    if (!_inFindMode) return;
    
    id item = [_outline selectedItem];
    if (!item) {
        item = [_outline child:0 ofItem:nil];
    }
    [self _nextFindResult:item];
}

- (IBAction)previousFindResult:(id)sender {
    if (!_inFindMode) return;
    
    id item = [_outline selectedItem];
    [self _previousFindResult:item];
}

- (BOOL)selectFileAtPath:(NSString *)path {
    if (!path) return NO;
    
    [self resetAllFilters];
    GitDiffFile *file = [_inorderFiles firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"path = %@", path]];
    
    if (file) {
        [self selectFile:file];
        return YES;
    }
    
    return NO;
}

- (IBAction)commentFilterButtonToggled:(id)sender {
    [self updateFilteredDiff];
}

- (IBAction)searchFilterEdited:(id)sender {
    [self updateFilteredDiff];
}

- (IBAction)filterInNavigator:(id)sender {
    [_filterField.window makeFirstResponder:_filterField];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(nextFile:)) {
        return [self canGoNextFile];
    } else if (menuItem.action == @selector(previousFile:)) {
        return [self canGoPreviousFile];
    }
    return YES;
}

#pragma mark - Find in Files

- (void)cancelFindMode {
    BOOL wasInFindMode = _inFindMode;
    _inFindMode = NO;
    [_findProgress cancel];
    [_findField setStringValue:@""];
    [_findCancelButton setHidden:YES];
    if (wasInFindMode) {
        [_outline reloadData];
        [_outline expandItem:nil expandChildren:YES];
    }
}

- (void)enterFindMode {
    [self.view.window makeFirstResponder:_findField];
}

- (IBAction)findInFiles:(id)sender {
    [_findProgress cancel];
    
    if ([_findField.stringValue length] == 0) {
        [self cancelFindMode];
        return;
    }
    
    _inFindMode = YES;
    
    [_findResults removeAllObjects];
    _filteredFindResults = nil;
    
    [_outline reloadData];
    GitFileSearch *search = [GitFileSearch new];
    search.query = _findField.stringValue;
    search.flags =
    ([_findMenu itemWithTag:FindMenuTagCaseSensitive].state == NSOnState ? GitFileSearchFlagCaseInsensitive : 0) |
    ([_findMenu itemWithTag:FindMenuTagRegEx].state == NSOnState ? GitFileSearchFlagRegex : 0) |
    ([_findMenu itemWithTag:FindMenuTagChangedLinesOnly].state == NSOnState ? GitFileSearchFlagAddedLinesOnly : 0);
    
    _findProgress = [_activeDiff performTextSearch:search handler:^(NSArray<GitFileSearchResult *> *result) {
        [self incorporateFindResult:result];
    }];
}

- (void)updateFilteredFindResults {
    NSString *pathFilter = [_filterField.stringValue trim];
    BOOL mustBeCommented = _commentFilterButton.state == NSOnState;
    _filteredFindResults = [_findResults filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        
        NSArray *a = evaluatedObject;
        GitDiffFile *file = [[a firstObject] file];
        if (mustBeCommented && ![_commentedPaths containsObject:file.path]) {
            return NO;
        }
        
        if ([pathFilter length] && ![file.path localizedStandardContainsString:pathFilter]) {
            return NO;
        }
        
        return YES;
    }]];
}

- (void)incorporateFindResult:(NSArray<GitFileSearchResult *> *)result {
    if (!_inFindMode || !result) {
        return;
    }
    
    if (!_findResults) {
        _findResults = [NSMutableArray new];
    }
    
    // take advantage of the fact that we're called with results grouped by file
    [_findResults addObject:result];
    
    NSInteger prevCount = [_filteredFindResults count];
    [self updateFilteredFindResults];
    NSInteger newCount = [_filteredFindResults count];
    
    if (newCount != prevCount && newCount > 0) {
        [_outline beginUpdates];
        [_outline insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:newCount-1] inParent:nil withAnimation:NSTableViewAnimationEffectNone];
        [_outline endUpdates];
        [_outline expandItem:[_outline child:newCount-1 ofItem:nil]];
    }
}

- (IBAction)cancelFindInFiles:(id)sender {
    [self cancelFindMode];
}

- (IBAction)showFindInFilesMenu:(id)sender {
    [_findMenu popUpMenuPositioningItem:nil atLocation:CGPointMake(0, -6.0) inView:_findField];
}

- (IBAction)findInFilesMenuAction:(id)sender {
    NSMenuItem *item = sender;
    [item setState:[item state] == NSOnState ? NSOffState : NSOnState];
    [self findInFiles:sender];
}

- (void)controlTextDidBeginEditing:(NSNotification *)obj {
    [_findCancelButton setHidden:NO];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
    if (![[_findField stringValue] length]) {
        [self cancelFindMode];
    }
}

#pragma mark - Outline View

- (NSInteger)fileModeNumberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return _filteredDiff != nil ? 1 : 0;
    } else if ([item isKindOfClass:[GitFileTree class]]) {
        return [[item children] count];
    } else {
        NSAssert([item isKindOfClass:[GitDiffFile class]], nil);
        return 0;
    }
}

- (NSInteger)findModeNumberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return [_filteredFindResults count];
    } else if ([item isKindOfClass:[NSArray class]]) {
        return [item count];
    } else {
        NSAssert([item isKindOfClass:[GitFileSearchResult class]], nil);
        return 0;
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    return _inFindMode
        ? [self findModeNumberOfChildrenOfItem:item]
        : [self fileModeNumberOfChildrenOfItem:item];
}

- (id)fileModeChild:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return _filteredDiff.fileTree;
    } else if ([item isKindOfClass:[GitFileTree class]]) {
        return [item children][index];
    } else {
        return [NSNull null];
    }
}

- (id)findModeChild:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return _filteredFindResults[index];
    } else if ([item isKindOfClass:[NSArray class]]) {
        return [item objectAtIndex:index];
    } else {
        return [NSNull null];
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {
    return _inFindMode
    ? [self findModeChild:index ofItem:item]
    : [self fileModeChild:index ofItem:item];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    if (_inFindMode) {
        return YES;
    } else {
        return [item isKindOfClass:[GitDiffFile class]];
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    id item = [_outline selectedItem];
    if ([item isKindOfClass:[GitDiffFile class]]) {
        if (_selectedFile != item) {
            _selectedFile = item;
            [_delegate prSidebar:self didSelectGitDiffFile:item highlightingSearchResult:nil];
        }
    } else if ([item isKindOfClass:[GitFileSearchResult class]]) {
        _selectedFile = [item file];
        [_delegate prSidebar:self didSelectGitDiffFile:_selectedFile highlightingSearchResult:item];
    } else if (_inFindMode && [item isKindOfClass:[NSArray class]]) {
        _selectedFile = [[item firstObject] file];
        [_delegate prSidebar:self didSelectGitDiffFile:_selectedFile highlightingSearchResult:nil];
    }
}

- (NSView *)fileModeViewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    PRSidebarCellView *cell = [_outline makeViewWithIdentifier:@"DataCell" owner:self];
    
    if (item == _filteredDiff.fileTree) {
        // root item
        cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
        cell.filename = self.pr.issue.repository.name;
        cell.changeType = @"";
        cell.hasComments = NO;
    } else if ([item isKindOfClass:[GitFileTree class]]) {
        cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
        cell.filename = [item name];
        cell.changeType = @"";
        cell.hasComments = NO;
    } else {
        GitDiffFile *file = item;
        NSString *filename = [item name];
        if (file.mode == DiffFileModeCommit) {
            cell.imageView.image = [NSImage imageNamed:@"Submodule"];
        } else {
            cell.imageView.image = [[NSWorkspace sharedWorkspace] iconForFileType:[filename pathExtension]];
        }
        cell.filename = filename;
        
        NSString *opTooltip = nil;
        NSString *op = @"";
        switch ([file operation]) {
            case DiffFileOperationAdded:
                op = @"A";
                break;
            case DiffFileOperationCopied:
                op = @"A+";
                break;
            case DiffFileOperationRenamed:
                op = @"R";
                opTooltip = [NSString stringWithFormat:NSLocalizedString(@"Renamed from %@", nil), file.oldPath];
                break;
            case DiffFileOperationDeleted:
                op = @"D";
                break;
            case DiffFileOperationModified:
                op = @"M";
                break;
            case DiffFileOperationTypeChange:
                op = @"M";
                break;
            case DiffFileOperationTypeConflicted:
                op = @"C";
                break;
        }
        cell.changeType = op;
        cell.changeLabel.toolTip = opTooltip;
        
        cell.hasComments = [_commentedPaths containsObject:file.path];
    }
    
    return cell;
}

- (NSView *)findModeViewForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([item isKindOfClass:[GitFileSearchResult class]]) {
        PRSidebarFindFileResultCellView *cell = [_outline makeViewWithIdentifier:@"ResultCell" owner:self];
        cell.result = item;
        return cell;
    } else {
        return [self fileModeViewForTableColumn:tableColumn item:[[item firstObject] file]];
    }
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    return _inFindMode
        ? [self findModeViewForTableColumn:tableColumn item:item]
        : [self fileModeViewForTableColumn:tableColumn item:item];
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
    if ([item isKindOfClass:[GitFileSearchResult class]]) {
        if (!_findResultSizingView) {
            _findResultSizingView = [outlineView makeViewWithIdentifier:@"ResultCell" owner:self];
        }
        CGFloat indent = [outlineView indentationPerLevel] * [outlineView levelForItem:item];
        _findResultSizingView.frame = CGRectMake(0.0,
                                       0.0,
                                       outlineView.bounds.size.width - (indent + outlineView.intercellSpacing.width * 2.0),
                                       100.0);
        _findResultSizingView.result = item;
        CGFloat height = [_findResultSizingView heightForWidth:_findResultSizingView.frame.size.width];
        return height;
    } else {
        return [outlineView rowHeight];
    }
}

@end

@implementation PRSidebarOutlineView

- (BOOL)acceptsFirstResponder { return NO; }

- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend {
    [super selectRowIndexes:indexes byExtendingSelection:extend];
}

@end


@implementation PRSidebarRowView

@end

@implementation PRSidebarCellView

- (void)setChangeType:(NSString *)changeType {
    _changeLabel.stringValue = changeType ?: @"";
}

- (NSString *)changeType {
    return _changeLabel.stringValue;
}

- (void)setHasComments:(BOOL)hasComments {
    _hasComments = hasComments;
    _commentWidthConstraint.constant = hasComments ? 14.0 : 0.0;
}

- (void)setFilename:(NSString *)filename {
    self.textField.stringValue = filename ?: @"";
}

- (NSString *)filename {
    return self.textField.stringValue;
}

@end

@implementation PRSidebarFindFileResultCellView {
    NSAttributedString *_resultStr;
}

- (void)setResult:(GitFileSearchResult *)result {
    // 3 times longer than you deserve :P
    const NSInteger MaxLineLength = 240;
    
    NSInteger sliceLen = 0;
    NSString *text = result.matchedLineText;
    if ([text length] > MaxLineLength) {
        NSRange first = [[result.matchedResults firstObject] range];
        text = [text substringFromIndex:first.location];
        if ([text length] > MaxLineLength) {
            text = [text substringToIndex:MaxLineLength];
        }
        sliceLen = first.location;
    }
    
    NSInteger leadingWhitespace = 0;
    NSCharacterSet *ws = [NSCharacterSet whitespaceCharacterSet];
    while (leadingWhitespace < [text length] && [ws characterIsMember:[text characterAtIndex:leadingWhitespace]]) {
        leadingWhitespace++;
    }
    
    if (leadingWhitespace) {
        sliceLen += leadingWhitespace;
        text = [text substringFromIndex:leadingWhitespace];
    }
    
    // make an attributed string
    const CGFloat fontSize = 11.0;
    NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
    para.lineBreakMode = NSLineBreakByCharWrapping;
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:text attributes:@{ NSFontAttributeName : [NSFont userFixedPitchFontOfSize:fontSize], NSForegroundColorAttributeName : [NSColor blackColor], NSParagraphStyleAttributeName : para }];
    
    NSColor *highlight = [NSColor colorWithRed:0.945 green:0.925 blue:0.714 alpha:1.0];
    NSColor *underline = [NSColor colorWithRed:0.894 green:0.765 blue:0.0 alpha:1.0];
    
    for (NSTextCheckingResult *cr in result.matchedResults) {
        NSRange r = cr.range;
        NSInteger nextLoc = r.location;
        nextLoc -= sliceLen;
        nextLoc = MAX(0, nextLoc);
        r.location = nextLoc;
        
        if (text.length <= r.location) {
            continue;
        }
        if (text.length < r.location + r.length) {
            r.length = text.length - r.location;
        }
        
        [str addAttributes:@{ NSBackgroundColorAttributeName : highlight, NSUnderlineColorAttributeName : underline, NSUnderlineStyleAttributeName : @YES } range:r];
    }
    
    _resultStr = str;
}

static const CGFloat xInset = 4.0;
static const CGFloat yInset = 4.0;
static const CGFloat iconSize = 16.0;
static const CGFloat iconPadding = 4.0;

static CGFloat sizeStr(NSAttributedString *str, CGFloat width, NSUInteger maxLines) {
    CGRect rect = CGRectMake(0, 0, width, 1000.0);
    CGPathRef path = CGPathCreateWithRect(rect, NULL);
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)str);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, str.length), path, NULL);
    CFRelease(path);
    
    CFArrayRef lines = CTFrameGetLines(frame);
    NSUInteger lineCount = MIN(CFArrayGetCount(lines), maxLines-1);
    
    if (lineCount == 0) {
        CFRelease(frame);
        CFRelease(framesetter);
        return 0;
    }
    
    CGPoint origin = CGPointZero;
    CTFrameGetLineOrigins(frame, CFRangeMake(lineCount-1, 1), &origin);
    
    CFRelease(frame);
    CFRelease(framesetter);
    
    return rect.size.height - origin.y;
}

- (CGFloat)heightForWidth:(CGFloat)width {
    CGFloat textWidth = width - xInset - iconSize - iconPadding;
    CGFloat baseHeight = sizeStr(_resultStr, textWidth, 3);
    CGFloat height = baseHeight + 2 * yInset;
    
    height = MAX(height, iconSize + 2*yInset);
    
    return height;
}

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
    NSAttributedString *str = _resultStr;
    if (self.backgroundStyle == NSBackgroundStyleDark) {
        NSMutableAttributedString *mstr = [str mutableCopy];
        [mstr setAttributes:@{ NSForegroundColorAttributeName : [NSColor whiteColor] } range:NSMakeRange(0, mstr.length)];
        str = mstr;
    }
    CGRect b = self.bounds;
    CGRect r = CGRectMake(iconSize + iconPadding,
                          yInset,
                          b.size.width - iconSize - iconPadding - xInset,
                          b.size.height);
    
    if (b.size.height == iconSize + 2 * yInset) {
        // single line, so center text
        r.origin.y += 2.0;
    }
    
    [str drawWithTruncationInRect:r];
    
    NSImage *icon = [NSImage imageNamed:@"TextFindResult"];
    [icon drawInRect:CGRectMake(0, yInset, iconSize, iconSize)];
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle {
    [super setBackgroundStyle:backgroundStyle];
    [self setNeedsDisplay:YES];
}

@end

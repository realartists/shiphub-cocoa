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
#import "GitDiff.h"
#import "NSImage+Icons.h"

@interface PRSidebarCellView : NSTableCellView

@property IBOutlet NSTextField *changeLabel;
@property IBOutlet NSLayoutConstraint *commentWidthConstraint;

@property (nonatomic, assign) BOOL hasComments;
@property (nonatomic, copy) NSString *changeType;
@property (nonatomic, copy) NSString *filename;

@end

@interface PRSidebarRowView : NSTableRowView

@end

@interface PRSidebarOutlineView : NSOutlineView

@end

@interface PRSidebarViewController () <NSOutlineViewDelegate, NSOutlineViewDataSource>

@property IBOutlet PRSidebarOutlineView *outline;

@property IBOutlet NSSearchField *filterField;
@property IBOutlet NSButton *commentFilterButton;

@property GitDiff *filteredDiff;
@property NSArray *inorderFiles;
@property NSSet *commentedPaths;

@end

@implementation PRSidebarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)reloadData {
    GitDiffFile *file = [_outline selectedItem];
    [_outline reloadData];
    [self selectFile:file];
}

- (void)setPr:(PullRequest *)pr {
    NSAssert(pr.spanDiff != nil, nil);
    
    _pr = pr;
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
    [self reloadData];
    [_outline expandItem:nil expandChildren:YES];
    if (![_outline selectedItem]) {
        [self selectFirstItem];
    }
}

- (void)selectFirstItem {
    GitDiffFile *first = [_inorderFiles firstObject];
    if (first) {
        [self selectFile:first];
    }
}

- (void)selectFile:(GitDiffFile *)item {
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
    if (row != NSNotFound) {
        [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
}

- (BOOL)canGoNextFile {
    id item = [_outline selectedItem];
    if (item) {
        NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
        return (idx+1 < _inorderFiles.count);
    }
    return NO;
}

- (BOOL)canGoPreviousFile {
    id item = [_outline selectedItem];
    if (item) {
        NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
        return idx-1 >= 0;
    }
    return NO;
}

- (IBAction)nextFile:(id)sender {
    id item = [_outline selectedItem];
    if (item) {
        NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
        if (idx+1 < _inorderFiles.count) {
            [self selectFile:_inorderFiles[idx+1]];
        }
    }
}

- (IBAction)previousFile:(id)sender {
    id item = [_outline selectedItem];
    if (item) {
        NSInteger idx = [_inorderFiles indexOfObjectIdenticalTo:item];
        if (idx-1 >= 0) {
            [self selectFile:_inorderFiles[idx-1]];
        }
    }
}

- (IBAction)nextCommentedFile:(id)sender {
    id item = [_outline selectedItem];
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

- (IBAction)previousCommentedFile:(id)sender {
    id item = [_outline selectedItem];
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

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return _filteredDiff != nil ? 1 : 0;
    } else if ([item isKindOfClass:[GitFileTree class]]) {
        return [[item children] count];
    } else {
        NSAssert([item isKindOfClass:[GitDiffFile class]], nil);
        return 0;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {
    if (item == nil) {
        return _filteredDiff.fileTree;
    } else if ([item isKindOfClass:[GitFileTree class]]) {
        return [item children][index];
    } else {
        return [NSNull null];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return [item isKindOfClass:[GitDiffFile class]];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    id item = [_outline selectedItem];
    if ([item isKindOfClass:[GitDiffFile class]]) {
        if (_selectedFile != item) {
            _selectedFile = item;
            [_delegate prSidebar:self didSelectGitDiffFile:item];
        }
    }
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    PRSidebarCellView *cell = [outlineView makeViewWithIdentifier:@"DataCell" owner:self];
    
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
        cell.imageView.image = [[NSWorkspace sharedWorkspace] iconForFileType:[filename pathExtension]];
        cell.filename = filename;
        
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
        
        cell.hasComments = [_commentedPaths containsObject:file.path];
    }
    
    return cell;
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

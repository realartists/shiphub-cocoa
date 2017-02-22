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
#import "GitDiff.h"
#import "NSImage+Icons.h"

@interface PRSidebarViewController () <NSOutlineViewDelegate, NSOutlineViewDataSource>

@property IBOutlet NSOutlineView *outline;
@property (nonatomic) GitDiff *activeDiff;

@end

@implementation PRSidebarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setPr:(PullRequest *)pr {
    NSAssert(pr.spanDiff != nil, nil);
    
    _pr = pr;
    self.activeDiff = pr.spanDiff;
}

- (void)setActiveDiff:(GitDiff *)diff {
    if (_activeDiff != diff) {
        _activeDiff = diff;
        [_outline reloadData];
        [_outline expandItem:nil expandChildren:YES];
        [self selectFirstItem];
    }
}

- (void)selectFirstItem {
    for (NSUInteger i = 0; i < _outline.numberOfRows; i++) {
        id item = [_outline itemAtRow:i];
        if ([item isKindOfClass:[GitDiffFile class]]) {
            [_outline selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
            break;
        }
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return _activeDiff != nil ? 1 : 0;
    } else if ([item isKindOfClass:[GitFileTree class]]) {
        return [[item children] count];
    } else {
        NSAssert([item isKindOfClass:[GitDiffFile class]], nil);
        return 0;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {
    if (item == nil) {
        return _activeDiff.fileTree;
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
        [_delegate prSidebar:self didSelectGitDiffFile:item];
    }
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    NSTableCellView *cell = [outlineView makeViewWithIdentifier:@"DataCell" owner:self];
    
    if (item == _activeDiff.fileTree) {
        // root item
        cell.imageView.image = [NSImage overviewIconNamed:@"Repo"];
        cell.textField.stringValue = self.pr.issue.repository.name;
    } else if ([item isKindOfClass:[GitFileTree class]]) {
        cell.imageView.image = [NSImage imageNamed:NSImageNameFolder];
        cell.textField.stringValue = [item name];
    } else {
        NSString *filename = [item name];
        cell.imageView.image = [[NSWorkspace sharedWorkspace] iconForFileType:[filename pathExtension]];
        cell.textField.stringValue = [item name];
    }
    
    return cell;
}

@end

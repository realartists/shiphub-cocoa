//
//  PRCommitController.m
//  ShipHub
//
//  Created by James Howard on 3/23/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRCommitController.h"

#import "Extras.h"
#import "GitCommit.h"
#import "GitDiff.h"
#import "PullRequest.h"

@interface PRCommitCellView : NSTableCellView

@property IBOutlet NSTextField *committishField;
@property IBOutlet NSTextField *dateField;
@property IBOutlet NSTextField *authorField;
@property IBOutlet NSTextField *messageField;

@end

@interface PRSpanCellView : NSTableCellView

@property IBOutlet NSTextField *titleField;
@property IBOutlet NSTextField *subtitleField;

@property (nonatomic, getter=isEnabled) BOOL enabled;

@end

@interface PRCommitController () <NSTableViewDelegate, NSTableViewDataSource>

@property IBOutlet NSTableView *table;

@property PRCommitCellView *sizingCell;

@end

@implementation PRCommitController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _table.enclosingScrollView.scrollerStyle = NSScrollerStyleOverlay;
    _table.rowHeight = 10000;
    
    _table.allowsMultipleSelection = NO; // showing multiple commits at once is very doable, but punting on it for the moment
}

- (void)setPr:(PullRequest *)pr {
    if (_pr != pr) {
        _pr = pr;
        [_table reloadData];
    }
}

#pragma mark NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return 4 + _pr.commits.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (row == 0) {
        NSTableCellView *header1 = [tableView makeViewWithIdentifier:@"HeaderCell" owner:self];
        header1.textField.stringValue = NSLocalizedString(@"Commits", nil);
        return header1;
    } else if (row == 1) {
        PRSpanCellView *span1 = [tableView makeViewWithIdentifier:@"SpanCell" owner:self];
        span1.enabled = YES;
        span1.titleField.stringValue = NSLocalizedString(@"Show all changes", nil);
        if (_pr.commits.count == 1) {
            span1.subtitleField.stringValue = NSLocalizedString(@"1 Commit", nil);
        } else {
            span1.subtitleField.stringValue = [NSString localizedStringWithFormat:NSLocalizedString(@"%td commits", nil), _pr.commits.count];
        }
        return span1;
    } else if (row == 2) {
        PRSpanCellView *span2 = [tableView makeViewWithIdentifier:@"SpanCell" owner:self];
        
        BOOL haveLastReview = _pr.spanDiffSinceMyLastReview != nil;
        BOOL changedSinceMyLastReview = haveLastReview && ![_pr.spanDiffSinceMyLastReview.baseRev isEqualToString:_pr.spanDiffSinceMyLastReview.headRev];
        
        span2.enabled = changedSinceMyLastReview;
        
        span2.titleField.stringValue = NSLocalizedString(@"Show changes since your last review", nil);
        
        if (!haveLastReview) {
            span2.subtitleField.stringValue = NSLocalizedString(@"You haven't reviewed this pull request yet", nil);
        } else if (haveLastReview && !changedSinceMyLastReview) {
            span2.subtitleField.stringValue = NSLocalizedString(@"No new changes", nil);
        } else {
            NSInteger filesChanged = _pr.spanDiffSinceMyLastReview.allFiles.count;
            if (filesChanged == 1) {
                span2.subtitleField.stringValue = NSLocalizedString(@"1 file changed", nil);
            } else {
                span2.subtitleField.stringValue = [NSString localizedStringWithFormat:NSLocalizedString(@"%td files changed", nil), filesChanged];
            }
        }
        
        return span2;
    } else if (row == 3) {
        NSTableCellView *header2 = [tableView makeViewWithIdentifier:@"HeaderCell" owner:self];
        header2.textField.stringValue = NSLocalizedString(@"Select Commit", nil);
        return header2;
    } else {
        GitCommit *commit = _pr.commits[row-4];
        PRCommitCellView *cell = [tableView makeViewWithIdentifier:@"CommitCell" owner:self];
        cell.committishField.stringValue = [commit.rev substringToIndex:7];
        cell.dateField.stringValue = [commit.date shortUserInterfaceString];
        if ([commit.authorEmail length]) {
            cell.authorField.stringValue = [NSString stringWithFormat:@"%@ <%@>", commit.authorName, commit.authorEmail];
        } else {
            cell.authorField.stringValue = commit.authorName ?: NSLocalizedString(@"Unknown Committer", nil);
        }
        cell.messageField.stringValue = [commit.message trim] ?: NSLocalizedString(@"No commit message", nil);
        return cell;
    }
    return nil;
}

#pragma mark NSTableViewDelegate

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    if (row == 0) {
        return 17.0;
    } else if (row < 3) {
        return 40.0;
    } else if (row == 3) {
        return 17.0;
    } else {
        if (!_sizingCell) {
            _sizingCell = [tableView makeViewWithIdentifier:@"CommitCell" owner:self];
        }
        _sizingCell.frame = CGRectMake(0.0,
                                       0.0,
                                       tableView.bounds.size.width - (tableView.intercellSpacing.width * 2.0),
                                       100.0);
        GitCommit *commit = _pr.commits[row-4];
        _sizingCell.messageField.stringValue = [commit.message trim] ?: @"";
        CGSize size = _sizingCell.messageField.fittingSize;
        return size.height + 41.0;
    }
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    return row == 0 || row == 3;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    if (row == 0) {
        return NO;
    } else if (row == 1) {
        return YES;
    } else if (row == 2) {
        PRSpanCellView *span2 = [tableView viewAtColumn:0 row:row makeIfNecessary:NO];
        return span2.enabled;
    } else if (row == 3) {
        return NO;
    } else {
        return YES;
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = _table.selectedRow;
    if (row == -1) return;
    
    if (row == 1) {
        [self.delegate commitControllerDidSelectSpanDiff:self];
    } else if (row == 2) {
        [self.delegate commitControllerDidSelectSinceReviewSpanDiff:self];
    } else if (row > 3) {
        GitCommit *commit = _pr.commits[row-4];
        DebugLog(@"Commit %p", commit);
        [self.delegate commitController:self didSelectCommit:commit];
    }
    [_table.animator selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
}

@end

@implementation PRSpanCellView

- (void)updateDisplay {
    if (self.backgroundStyle == NSBackgroundStyleLight) {
        _titleField.textColor = self.enabled ? [NSColor blackColor] : [NSColor secondaryLabelColor];
        _subtitleField.textColor = self.enabled ? [NSColor blackColor] : [NSColor secondaryLabelColor];
    } else {
        _titleField.textColor = [NSColor whiteColor];
        _subtitleField.textColor = [NSColor whiteColor];
    }
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    [self updateDisplay];
}

- (void)setEnabled:(BOOL)enabled {
    if (_enabled != enabled) {
        _enabled = enabled;
        [self updateDisplay];
    }
}

@end

@implementation PRCommitCellView

- (void)updateDisplay {
    if (self.backgroundStyle == NSBackgroundStyleLight) {
        _committishField.textColor = [NSColor secondaryLabelColor];
        _dateField.textColor = [NSColor secondaryLabelColor];
        _authorField.textColor = [NSColor blackColor];
        _messageField.textColor = [NSColor blackColor];
    } else {
        _committishField.textColor = [NSColor whiteColor];
        _dateField.textColor = [NSColor whiteColor];
        _authorField.textColor = [NSColor whiteColor];
        _messageField.textColor = [NSColor whiteColor];
    }
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    [super setBackgroundStyle:backgroundStyle];
    [self updateDisplay];
}

@end

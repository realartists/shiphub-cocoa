//
//  Issue3PaneTableController.m
//  ShipHub
//
//  Created by James Howard on 5/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Issue3PaneTableController.h"

#import "CompactIssueCellViewController.h"
#import "Extras.h"
#import "IssueTableControllerPrivate.h"

@interface CompactIssueTable : ProblemTableView

@end

@interface Issue3PaneTableController ()

@property NSMutableDictionary *activeRows;
@property NSMutableArray *reuseQueue;

@end

@implementation Issue3PaneTableController

+ (Class)tableClass {
    return [CompactIssueTable class];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.table setHeaderView:nil];
    [self.table setUsesAlternatingRowBackgroundColors:NO];
    [self.table setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
}

- (void)commonInit {
    [super commonInit];
    self.defaultColumns = [NSSet setWithArray:@[@"issue.number"]];
}

- (CompactIssueCellViewController *)viewControllerForRow:(NSInteger)row {
    if (!_activeRows) {
        _activeRows = [NSMutableDictionary new];
        _reuseQueue = [NSMutableArray new];
    }
    
    CompactIssueCellViewController *vc = _activeRows[@(row)];
    if (!vc) {
        vc = [_reuseQueue lastObject];
        if (!vc) {
            vc = [CompactIssueCellViewController new];
        } else {
            [_reuseQueue removeLastObject];
        }
        
        _activeRows[@(row)] = vc;
    }
    
    return vc;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    return nil;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    return (id)[self viewControllerForRow:row].view;
}

- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    CompactIssueCellViewController *vc = [self viewControllerForRow:row];
    vc.issue = [self.items[row] issue];
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    CompactIssueCellViewController *vc = _activeRows[@(row)];
    if (vc) {
        if (_reuseQueue.count < 10) {
            [_reuseQueue addObject:vc];
        }
        [_activeRows removeObjectForKey:@(row)];
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return [CompactIssueCellViewController cellHeight];
}

@end

@implementation CompactIssueTable

- (void)drawGridInClipRect:(NSRect)clipRect
{
    
}

@end

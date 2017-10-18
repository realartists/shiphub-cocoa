//
//  LabelsFilterTableController.m
//  Ship
//
//  Created by James Howard on 10/16/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "LabelsFilterTableController.h"

#import "Extras.h"
#import "Label.h"
#import "LabelsControl.h"

@interface LabelsFilterSearchField : NSSearchField

@end

@interface LabelsFilterTableView : NSTableView

@end

@interface LabelsFilterTableCellView : NSTableCellView

@property IBOutlet NSButton *check;
@property IBOutlet LabelsControl *label;

@end

@interface LabelsFilterTableController () <NSTableViewDataSource, NSTableViewDelegate>

@property IBOutlet NSTableView *table;
@property IBOutlet NSSearchField *search;

@property (nonatomic, strong) NSArray *filteredLabels;
@property (nonatomic, copy) NSArray *labels;
@property (nonatomic, copy) NSMutableSet *selectedLabelNames;

- (void)tableDidClickRow:(NSInteger)row;

@end

@implementation LabelsFilterTableController

- (NSString *)nibName { return @"LabelsFilterTableController"; }

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [self clearSearch];
    [self.table.enclosingScrollView scrollToBeginningOfDocument:nil];
}

- (CGSize)preferredMaximumSize {
    CGFloat chromeHeight = 332.0 - 306.0;
    CGFloat spaceHeight = _table.intercellSpacing.height * (_labels.count + 1);
    
    CGFloat tableHeight = (_table.rowHeight * _labels.count) + spaceHeight;
    return CGSizeMake(258.0, MAX(60.0, chromeHeight + tableHeight));
}

- (void)setLabels:(NSArray<Label *> *)labels selected:(NSSet<NSNumber *> *)selected {
    if (![_labels isEqualToArray:labels] || ![_selectedLabelNames isEqualToSet:selected]) {
        _labels = [labels copy];
        _selectedLabelNames = [selected mutableCopy] ?: [NSMutableSet set];
        [self filterSortAndUpdate];
    }
}

- (void)filterSortAndUpdate {
    NSString *search = [_search.stringValue trim];
    if ([search length]) {
        _filteredLabels = [_labels filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", search]];
    } else {
        _filteredLabels = _labels;
    }
    _filteredLabels = [_filteredLabels sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)]]];
    [_table reloadData];
}

- (void)clearSearch {
    if (_search.stringValue.length != 0) {
        _search.stringValue = @"";
        [self filterSortAndUpdate];
    }
}

- (void)clearSelections {
    _search.stringValue = @"";
    _selectedLabelNames = [NSMutableSet new];
    [self filterSortAndUpdate];
}

- (IBAction)searchFieldChanged:(id)sender {
    [self filterSortAndUpdate];
    if ([[NSApp currentEvent] isReturn]) {
        if ([_filteredLabels count] > 0) {
            LabelsFilterTableCellView *cell = [_table viewAtColumn:0 row:0 makeIfNecessary:YES];
            [cell.check performClick:nil];
        }
    }
    if (![_search isFirstResponder]) {
        [self.view.window makeFirstResponder:_search];
    }
}

- (IBAction)labelCheckChanged:(NSButton *)sender {
    NSInteger row = [_table rowForView:sender];
    if (row != -1) {
        Label *label = _filteredLabels[row];
        if ([sender state] == NSOnState) {
            [_selectedLabelNames addObject:label.name];
        } else {
            [_selectedLabelNames removeObject:label.name];
        }
    }
    [self.delegate labelsFilterTableController:self didUpdateSelectedLabelNames:_selectedLabelNames];
}

- (void)tableDidClickRow:(NSInteger)row {
    LabelsFilterTableCellView *cell = [_table viewAtColumn:0 row:row makeIfNecessary:YES];
    [cell.check performClick:nil];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_filteredLabels count];
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return NO;
}

- (NSString *)tableView:(NSTableView *)tableView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return [_filteredLabels[row] name];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    Label *label = _filteredLabels[row];
    LabelsFilterTableCellView *cell = [tableView makeViewWithIdentifier:@"LabelCell" owner:self];
    
    cell.label.labels = @[label];
    
    cell.check.state = [_selectedLabelNames containsObject:label.name] ? NSOnState: NSOffState;
    
    return cell;
}

@end

@implementation LabelsFilterSearchField

@end

@implementation LabelsFilterTableView

- (BOOL)canBecomeKeyView { return NO; }
- (BOOL)acceptsFirstResponder { return NO; }

- (void)mouseDown:(NSEvent *)event {
    LabelsFilterTableController *c = (id)self.delegate;
    CGPoint p = [event locationInWindow];
    p = [self convertPoint:p fromView:nil];
    NSInteger row = [self rowAtPoint:p];
    if (row >= 0 && row < self.numberOfRows) {
        [c tableDidClickRow:row];
    }
}

@end

@implementation LabelsFilterTableCellView

@end


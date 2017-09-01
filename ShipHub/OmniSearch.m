//
//  OmniSearch.m
//  ShipHub
//
//  Created by James Howard on 8/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "OmniSearch.h"

#import "Extras.h"
#import "OmniSearchCellViewController.h"

#import <objc/runtime.h>

@protocol OmniSearchTextFieldDelegate <NSTextFieldDelegate>

- (void)controlTextDidSubmit:(NSNotification *)note;
- (void)controlTextDidAbort:(NSNotification *)note;
- (void)controlTextNavigateUp:(NSNotification *)note;
- (void)controlTextNavigateDown:(NSNotification *)note;

@end

@interface OmniSearchTextField : NSTextField

@property (weak) id<OmniSearchTextFieldDelegate> delegate;

@end

@interface OmniSearchFieldEditor : NSTextView

@end

@interface OmniSearchTable : NSTableView

@end

@interface OmniSearchRowView : NSTableRowView

@end

@interface OmniSearchWindow : NSWindow

@end

@interface OmniSearch () <NSWindowDelegate, NSTableViewDelegate, NSTableViewDataSource, OmniSearchTextFieldDelegate>

@property NSView *containerView;
@property NSTableView *table;
@property NSMutableSet *activeCellControllers;
@property NSMutableArray *freeCellControllers;
@property NSMutableArray *freeRows;
@property OmniSearchTextField *queryField;
@property NSImageView *searchImage;

@property (nonatomic, copy) NSArray<OmniSearchItem *> *items;

@property NSTimer *queryTimer;
@property NSInteger searchToken;

@property id localMouseDownEventMonitor;
@property id lostFocusObserver;

@end

@implementation OmniSearch

- (id)init {
    NSWindow *window = [[OmniSearchWindow alloc] initWithContentRect:CGRectMake(0, 0, 200, 200) styleMask:0 backing:NSBackingStoreBuffered defer:YES];
    
    window.opaque = NO;
    window.backgroundColor = [NSColor clearColor];
    
    NSView *contentView = window.contentView;
    contentView.wantsLayer = YES;
    contentView.layer.opaque = NO;
    contentView.layer.cornerRadius = 6.0;
    [contentView.layer setMasksToBounds:YES];
    contentView.layer.backgroundColor = [[NSColor clearColor] CGColor];
    
    NSVisualEffectView *effect = [[NSVisualEffectView alloc] initWithFrame:contentView.frame];
    effect.material = NSVisualEffectMaterialPopover;
    effect.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    effect.state = NSVisualEffectStateActive;
    self.containerView = effect;
    [contentView addSubview:effect];
    
    [window setHasShadow:NO];
    [window setHasShadow:YES];
    
    window.delegate = self;
    
    if (self = [super initWithWindow:window]) {
        [self buildViews];
    }
    
    return self;
}

- (void)buildViews {
    NSImage *searchImage = [NSImage imageNamed:@"OpenQuicklyMagnifyingGlass"];
    searchImage.template = YES;
    
    NSImageView *imageView = [[NSImageView alloc] initWithFrame:CGRectMake(0, 0, 23, 23)];
    imageView.editable = NO;
    imageView.imageFrameStyle = NSImageFrameNone;
    imageView.allowsCutCopyPaste = NO;
    imageView.imageAlignment = NSImageAlignCenter;
    imageView.imageScaling = NSImageScaleProportionallyDown;
    imageView.image = searchImage;
    self.searchImage = imageView;
    [self.containerView addSubview:imageView];
    
    OmniSearchTextField *queryField = [[OmniSearchTextField alloc] initWithFrame:CGRectZero];
    queryField.placeholderString = NSLocalizedString(@"Search", nil);
    queryField.font = [NSFont systemFontOfSize:22.0];
    queryField.bordered = NO;
    queryField.bezeled = NO;
    queryField.editable = YES;
    queryField.drawsBackground = NO;
    queryField.focusRingType = NSFocusRingTypeNone;
    queryField.delegate = self;
    [queryField sizeToFit];
    self.queryField = queryField;
    [self.containerView addSubview:queryField];
    
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:CGRectZero];
    scroll.hasHorizontalScroller = NO;
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSNoBorder;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    scroll.verticalScroller.controlSize = NSSmallControlSize;
    scroll.autohidesScrollers = YES;
    scroll.drawsBackground = NO;
    
    NSTableView *table = [[OmniSearchTable alloc] init];
    table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    table.allowsColumnReordering = NO;
    table.allowsColumnResizing = NO;
    table.allowsColumnSelection = NO;
    table.rowHeight = 48.0;
    table.intercellSpacing = CGSizeZero;
    table.gridStyleMask = NSTableViewGridNone;
    table.backgroundColor = [NSColor clearColor];
    table.doubleAction = @selector(tableDoubleClicked:);
    table.target = self;
    table.backgroundColor = [NSColor clearColor];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"col"];
    col.minWidth = 1.0;
    col.maxWidth = 10000.0;
    col.title = @"Header";
    col.headerCell.alignment = NSTextAlignmentCenter;
    [table addTableColumn:col];
    [table setHeaderView:nil];
    [scroll setDocumentView:table];
    
    self.table = table;
    
    [self.containerView addSubview:scroll];
    
    table.delegate = self;
    table.dataSource = self;
}

- (void)sizeWindowAndLayout {
    NSScreen *screen = self.window.screen;
    CGRect screenRect = screen.frame;
    screenRect.size.height -= [[NSApp mainMenu] menuBarHeight];
    
    const CGFloat width = 600.0;
    const CGFloat headerHeight = 48.0;
    const CGFloat spaceToTopOfScreen = 140.0;
    
    CGFloat maxTableHeight = MIN(500.0, screenRect.size.height - spaceToTopOfScreen - headerHeight);
    
    CGFloat tableHeight = MIN(maxTableHeight, _items.count * _table.rowHeight);
    
    CGSize contentSize = CGSizeMake(width, tableHeight + headerHeight);
    [self.window setContentSize:contentSize];
    [self.window setFrameTopLeftPoint:CGPointMake((screenRect.size.width - contentSize.width) / 2.0, screenRect.size.height - spaceToTopOfScreen)];
    
    _containerView.frame = self.window.contentView.bounds;
    
    self.table.enclosingScrollView.frame = CGRectMake(0, 0, width, tableHeight);
    
    CGSize imageSize = self.searchImage.frame.size;
    self.searchImage.frame = CGRectMake(14.0,
                                        contentSize.height - ((headerHeight - imageSize.height) / 2.0) - imageSize.height,
                                        imageSize.width,
                                        imageSize.height);
    
    CGRect queryFrame = CGRectZero;
    [self.queryField sizeToFit];
    queryFrame.size.height = self.queryField.frame.size.height;
    queryFrame.origin.x = CGRectGetMaxX(self.searchImage.frame) + 8.0;
    queryFrame.origin.y = contentSize.height - ((headerHeight - queryFrame.size.height) / 2.0) - queryFrame.size.height;
    queryFrame.size.width = width - CGRectGetMaxX(self.searchImage.frame) - 8.0;
    self.queryField.frame = queryFrame;
}

- (void)showWindow:(id)sender {
    if (!self.window.visible) {
        _queryField.stringValue = @"";
        [self setItems:nil];
        
        __weak NSWindow *weakWindow = self.window;
        __weak __typeof(self) weakSelf = self;
        
        _localMouseDownEventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask|NSRightMouseDownMask|NSOtherMouseDown handler:^(NSEvent *event) {
            if ([event window] != weakWindow) {
                [weakSelf close];
            }
            
            return event;
        }];
        
        _lostFocusObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowDidResignKeyNotification object:self.window queue:nil usingBlock:^(NSNotification *arg1) {
            [weakSelf close];
        }];
    }
    [self.window makeFirstResponder:_queryField];
    [self.window makeKeyAndOrderFront:sender];
}

- (void)close {
    if (_lostFocusObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_lostFocusObserver];
        _lostFocusObserver = nil;
    }
    
    if (_localMouseDownEventMonitor) {
        [NSEvent removeMonitor:_localMouseDownEventMonitor];
        _localMouseDownEventMonitor = nil;
    }
    
    [super close];
}

- (void)setPlaceholderString:(NSString *)placeholderString {
    [self window];
    _queryField.placeholderString = placeholderString ?: @"";
}

- (NSString *)placeholderString {
    return _queryField.placeholderString;
}

- (void)setQueryString:(NSString *)queryString {
    [self window];
    _queryField.stringValue = queryString ?: @"";
}

- (NSString *)queryString {
    return _queryField.stringValue;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self scheduleQueryTimer];
}

- (void)controlTextDidAbort:(NSNotification *)note {
    [self close];
}

- (void)controlTextDidSubmit:(NSNotification *)note {
    NSInteger selectedRow = [_table selectedRow];
    if (selectedRow != -1) {
        [self.delegate omniSearch:self didSelectItem:_items[selectedRow]];
    }
    [self close];
}

- (void)controlTextNavigateUp:(NSNotification *)note {
    if (_table.numberOfRows == 0) return;
    NSInteger selectedRow = [_table selectedRow];
    selectedRow--;
    selectedRow = MAX(0, MIN(selectedRow, _table.numberOfRows-1));
    [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}

- (void)controlTextNavigateDown:(NSNotification *)note {
    if (_table.numberOfRows == 0) return;
    NSInteger selectedRow = [_table selectedRow];
    selectedRow++;
    selectedRow = MAX(0, MIN(selectedRow, _table.numberOfRows-1));
    [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
}

- (void)tableDoubleClicked:(id)sender {
    NSInteger clickedRow = [_table clickedRow];
    if (clickedRow != -1) {
        [self.delegate omniSearch:self didSelectItem:_items[clickedRow]];
        [self close];
    }
}

- (void)scheduleQueryTimer {
    if ([_queryTimer.userInfo[@"query"] isEqualToString:_queryField.stringValue]) {
        return; // nothing changed
    }
    
    [_queryTimer invalidate];
    _queryTimer = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(queryTimerFired:) userInfo:@{@"query":[_queryField.stringValue copy]} repeats:NO];
}

- (void)queryTimerFired:(NSTimer *)timer {
    _queryTimer = nil;
    
    NSString *query = [_queryField.stringValue trim];
    if (query.length == 0) {
        [self setItems:nil];
    }
    
    NSInteger searchToken = ++_searchToken;
    [self.delegate omniSearch:self itemsForQuery:query completion:^(NSArray<OmniSearchItem *> *items) {
        RunOnMain(^{
            if (searchToken == _searchToken) {
                [self setItems:items];
            }
        });
    }];
}

- (void)reloadData {
    if (self.window.isVisible) {
        [_queryTimer invalidate];
        _queryTimer = nil;
        [self queryTimerFired:nil];
    }
}

- (void)setItems:(NSArray<OmniSearchItem *> *)items {
    _items = [items copy];
    [self sizeWindowAndLayout];
    [_table reloadData];
    if (_items.count) {
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _items.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row {
    OmniSearchItem *item = _items[row];
    
    OmniSearchCellViewController *cell = [_freeCellControllers lastObject];
    if (cell) {
        [_freeCellControllers removeLastObject];
    } else {
        cell = [OmniSearchCellViewController new];
    }
    cell.item = item;
    
    if (!_activeCellControllers) {
        _activeCellControllers = [NSMutableSet new];
    }
    [_activeCellControllers addObject:cell];
    
    return cell.cellView;
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
    OmniSearchRowView *rowView = [_freeRows lastObject];
    if (rowView) {
        [_freeRows removeLastObject];
    } else {
        rowView = [OmniSearchRowView new];
    }
    
    return rowView;
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    NSTableCellView *cell = [rowView viewAtColumn:0];
    OmniSearchCellViewController *cellController = (id)[cell nextResponder];
    
    if (cellController && [cellController isKindOfClass:[OmniSearchCellViewController class]]) {
        if (!_freeCellControllers) {
            _freeCellControllers = [NSMutableArray new];
        }
        [_freeCellControllers addObject:cellController];
    }
    
    if (!_freeRows) {
        _freeRows = [NSMutableArray new];
    }
    
    [_freeRows addObject:rowView];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger row = [_table selectedRow];
    if (row != -1) {
        [_table scrollRowToVisible:row];
    }
}

@end

@implementation OmniSearchWindow

- (BOOL)canBecomeKeyWindow { return YES; }

@end

@implementation OmniSearchItem

@end

@implementation OmniSearchRowView

- (BOOL)isEmphasized {
    return self.selected;
}

- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    if (self.selected) {
        [[NSColor alternateSelectedControlColor] setFill];
        NSRectFill(dirtyRect);
    }
}

@end

@implementation OmniSearchTable

- (BOOL)acceptsFirstResponder { return NO; }
- (BOOL)canBecomeKeyView { return NO; }

@end

@interface OmniSearchTextFieldCell : NSTextFieldCell

@end

@implementation OmniSearchTextField

@dynamic delegate;

+ (Class)cellClass {
    return [OmniSearchTextFieldCell class];
}

@end

@implementation OmniSearchTextFieldCell

- (NSTextView *)fieldEditorForView:(NSView *)aControlView {
    NSWindow *window = [aControlView window];
    OmniSearchFieldEditor *view = objc_getAssociatedObject(window, @"OmniSearchFieldEditor");
    if (!view) {
        view = [[OmniSearchFieldEditor alloc] init];
        view.fieldEditor = YES;
        objc_setAssociatedObject(window, @"OmniSearchFieldEditor", view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return view;
}

@end

@implementation OmniSearchFieldEditor

- (void)keyDown:(NSEvent *)theEvent {
    OmniSearchTextField *field = (OmniSearchTextField *)self.delegate;
    
    if ([theEvent isArrowDown]) {
        [field.delegate controlTextNavigateDown:[NSNotification notificationWithName:@"down" object:field]];
    } else if ([theEvent isArrowUp]) {
        [field.delegate controlTextNavigateUp:[NSNotification notificationWithName:@"up" object:field]];
    } else if ([theEvent isReturn]) {
        [field.delegate controlTextDidSubmit:[NSNotification notificationWithName:@"submit" object:field]];
    } else if ([theEvent isEscape]) {
        [field.delegate controlTextDidAbort:[NSNotification notificationWithName:@"abort" object:field]];
    } else {
        [super keyDown:theEvent];
    }
}

@end

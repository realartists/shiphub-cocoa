//
//  ProblemTableController.m
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "IssueTableControllerPrivate.h"

#import "IssueDocumentController.h"

#import "DataStore.h"
#import "Extras.h"
#import "Issue.h"
#import "IssueIdentifier.h"
#import "UpNextHelper.h"
#import "BulkModifyHelper.h"
#import "LabelsView.h"

@interface MultipleAssigneesFormatter : NSFormatter
@end

@interface IssueTableController () <ProblemTableViewDelegate, NSTableViewDataSource, NSMenuDelegate>

@property (strong) IBOutlet NSTableView *table;

@property (strong) NSMutableArray *tableColumns; // NSTableView .tableColumns property doesn't preserve order, and we want this in our order.

@property (strong) NSMutableArray *items;
@property BOOL loading;
@property NSInteger loadGeneration;

@property BOOL animationInProgress;
@property NSInvocation *afterTableAnimation;

@end

@implementation IssueTableController

+ (Class)tableClass {
    return [ProblemTableView class];
}

- (void)commonInit {
    _items = [NSMutableArray array];
    _defaultColumns = [NSSet setWithArray:@[@"number", @"title", @"assignee.login", @"repository.fullName"]];
}

- (id)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    _table.dataSource = nil;
    _table.delegate = nil;
}

- (void)loadView {
    CGRect r = CGRectMake(0, 0, 600, 600);
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:r];
    scroll.hasVerticalScroller = YES;
    scroll.hasHorizontalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    
    NSTableView *table = [[[[self class] tableClass] alloc] initWithFrame:r];
    table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    table.allowsColumnReordering = YES;
    table.allowsColumnResizing = YES;
    table.allowsColumnSelection = NO;
    table.allowsMultipleSelection = YES;
    table.usesAlternatingRowBackgroundColors = [self usesAlternatingRowBackgroundColors];
    [scroll setDocumentView:table];
    
    _table = table;
    _table.delegate = self;
    _table.dataSource = self;
    
    self.view = scroll;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _table.doubleAction = @selector(tableViewDoubleClicked:);
    [_table setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    [_table registerForDraggedTypes:@[(__bridge NSString *)kUTTypeURL, (__bridge NSString *)kUTTypeRTF, (__bridge NSString *)kUTTypePlainText]];
    
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    [menu addItemWithTitle:NSLocalizedString(@"Open", nil) action:@selector(openFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy Issue #", nil) action:@selector(copyNumberFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy Issue # and Title", nil) action:@selector(copyNumberAndTitleFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy GitHub URL", nil) action:@selector(copyGitHubURLFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Mark As Read", nil) action:@selector(markAsReadFromMenu:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Up Next", nil) action:@selector(toggleUpNext:) keyEquivalent:@""];
    
    NSMenuItem *bulkMenuItem = [menu addItemWithTitle:@"Bulk Modify" action:nil keyEquivalent:@""];
    NSMenu *bulkMenu = [[NSMenu alloc] init];
    bulkMenuItem.submenu = bulkMenu;
    [bulkMenu addItemWithTitle:NSLocalizedString(@"Milestone", nil) action:@selector(bulkModifyMilestone:) keyEquivalent:@""];
    [bulkMenu addItemWithTitle:NSLocalizedString(@"Labels", nil) action:@selector(bulkModifyLabels:) keyEquivalent:@""];
    [bulkMenu addItemWithTitle:NSLocalizedString(@"Assignee", nil) action:@selector(bulkModifyAssignee:) keyEquivalent:@""];
    [bulkMenu addItemWithTitle:NSLocalizedString(@"State", nil) action:@selector(bulkModifyState:) keyEquivalent:@""];
    
    _table.menu = menu;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    _table.autosaveTableColumns = YES;
    _table.autosaveName = _autosaveName;
    
    [self _makeColumns];
    [self _makeColumnHeaderMenu];
}

+ (NSArray *)columnSpecs {
    static NSArray *specs;
    if (!specs) {
        specs = @[
                  @{ @"identifier" : @"unread",
                     @"title" : NSLocalizedString(@"•", nil),
                     @"menuTitle" : NSLocalizedString(@"Unread", nil),
                     @"formatter" : [BooleanDotFormatter new],
                     @"width" : @20,
                     @"maxWidth" : @20,
                     @"minWidth" : @20,
                     @"centered" : @YES,
                     @"cellClass" : @"ReadIndicatorCell",
                     @"titleFont" : [NSFont boldSystemFontOfSize:12.0] },
                  
                  @{ @"identifier" : @"number",
                     @"title" : NSLocalizedString(@"#", nil),
                     @"formatter" : [NSNumberFormatter positiveAndNegativeIntegerFormatter],
                     @"width" : @46,
                     @"maxWidth" : @46,
                     @"minWidth" : @46 },
                  
                  @{ @"identifier" : @"fullIdentifier",
                     @"title" : NSLocalizedString(@"Path", nil),
                     @"width" : @180,
                     @"maxWidth" : @260,
                     @"minWidth" : @60 },
                  
                  @{ @"identifier" : @"title",
                     @"title" : NSLocalizedString(@"Title", nil),
                     @"width" : @271,
                     @"minWidth" : @100,
                     @"maxWidth" : @10000 },
                  
                  @{ @"identifier" : @"assignees.login",
                     @"title" : NSLocalizedString(@"Assignee", nil),
                     @"formatter" : [MultipleAssigneesFormatter new],
                     @"sortDescriptor" : [NSSortDescriptor sortDescriptorWithKey:@"assignees.login" ascending:YES selector:@selector(localizedStandardCompareContents:)],
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"originator.login",
                     @"title" : NSLocalizedString(@"Originator", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"closedBy.login",
                     @"title" : NSLocalizedString(@"Resolver", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"repository.fullName",
                     @"title" : NSLocalizedString(@"Repo", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @250 },
                  
                  @{ @"identifier" : @"milestone.title",
                     @"title" : NSLocalizedString(@"Milestone", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @250 },
                  
                  @{ @"identifier" : @"state",
                     @"title" : NSLocalizedString(@"State", nil),
                     @"width" : @130,
                     @"minWidth" : @100,
                     @"maxWidth" : @150 },
                  
                  @{ @"identifier" : @"updatedAt",
                     @"title" : NSLocalizedString(@"Modified", nil),
                     @"formatter" : [NSDateFormatter shortDateAndTimeFormatter],
                     @"width" : @130 },
                  
                  @{ @"identifier" : @"createdAt",
                     @"formatter" : [NSDateFormatter shortDateAndTimeFormatter],
                     @"title" : NSLocalizedString(@"Created", nil),
                     @"width" : @130 },
                  
                  @{ @"identifier" : @"labels",
                     @"title" : NSLocalizedString(@"Labels", nil),
                     @"cellClass" : @"LabelsCell",
                     @"sortDescriptor" : [NSSortDescriptor sortDescriptorWithKey:@"labels.@count" ascending:YES],
                     @"minWidth" : @100,
                     @"maxWidth" : @10000 }
                  ];
    }
    return specs;
}

+ (NSDictionary *)columnSpecWithIdentifier:(NSString *)identifier {
    static NSMutableDictionary *lookups;
    if (!lookups) {
        lookups = [NSMutableDictionary new];
    }
    NSMutableDictionary *lookup = lookups[NSStringFromClass(self)];
    if (!lookup) {
        NSArray *specs = [self columnSpecs];
        lookup = [NSMutableDictionary dictionaryWithCapacity:[specs count]];
        for (NSDictionary *spec in specs) {
            lookup[spec[@"identifier"]] = spec;
        }
        lookups[NSStringFromClass(self)] = lookup;
    }
    return lookup[identifier];
}

- (void)_makeColumnHeaderMenu {
    //create our contextual menu
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    [[_table headerView] setMenu:menu];
    //loop through columns, creating a menu item for each
    for (NSTableColumn *col in _tableColumns) {
        NSDictionary *spec = [[self class] columnSpecWithIdentifier:col.identifier];
        NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle:spec[@"menuTitle"] ?: spec[@"title"]
                                                    action:@selector(toggleColumn:)  keyEquivalent:@""];
        mi.target = self;
        mi.representedObject = col;
        [menu addItem:mi];
    }
    
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *reset = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Reset to default", nil) action:@selector(resetColumns:) keyEquivalent:@""];
    reset.target = self;
    [menu addItem:reset];
    
    return;
}

- (void)toggleColumn:(id)sender {
    NSTableColumn *col = [sender representedObject];
    [col setHidden:![col isHidden]];
}

-(void)menuWillOpen:(NSMenu *)menu {
    if (menu == _table.headerView.menu) {
        for (NSMenuItem *mi in menu.itemArray) {
            NSTableColumn *col = [mi representedObject];
            if (col) {
                [mi setState:col.isHidden ? NSOffState : NSOnState];
            }
        }
    }
}

- (NSArray *)selectedItemsForMenu {
    NSInteger row = [_table clickedRow];
    NSMutableIndexSet *selectedIndexes = [[_table selectedRowIndexes] mutableCopy];
    
    if ([selectedIndexes containsIndex:row]) {
        return [_items objectsAtIndexes:selectedIndexes];
    } else if (row != NSNotFound && row < _items.count) {
        return @[_items[row]];
    } else {
        return nil;
    }
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == _table.menu) {
        NSArray *selected = [self selectedItemsForMenu];
        BOOL any = [selected count] > 0;
        for (NSMenuItem *item in menu.itemArray) {
            item.hidden = !any;
        }
    }
}

- (void)openFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }];
    [[IssueDocumentController sharedDocumentController] openIssuesWithIdentifiers:identifiers];
}

- (IBAction)copyNumberFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    [self copyNumbers:selected];
}

- (IBAction)copyNumberAndTitleFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    [self copyNumbersAndTitles:selected];
}

- (IBAction)copyGitHubURLFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    [[[selected firstObject] fullIdentifier] copyIssueGitHubURLToPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)markAsReadFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    for (Issue *i in selected) {
        if (i.unread) {
            [[DataStore activeStore] markIssueAsRead:i.fullIdentifier];
        }
    }
}

- (IBAction)toggleUpNext:(id)sender {
    NSArray *selected;
    if ([sender menu] == _table.menu) {
        selected = [self selectedItemsForMenu];
    } else {
        selected = [self selectedItems];
    }
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }];
    if ([identifiers count]) {
        if (_upNextMode) {
            [[UpNextHelper sharedHelper] removeFromUpNext:identifiers window:self.view.window completion:nil];
        } else {
            [[UpNextHelper sharedHelper] addToUpNext:identifiers atHead:NO window:self.view.window completion:nil];
        }
    }
}

- (void)removeFromUpNext:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }];
    if ([identifiers count]) {
        [[DataStore activeStore] removeFromUpNext:identifiers completion:nil];
    }
}

- (IBAction)bulkModifyMilestone:(id)sender {
    NSArray *selected;
    if ([[sender menu] supermenu] == _table.menu) {
        selected = [self selectedItemsForMenu];
    } else {
        selected = [self selectedItems];
    }
    
    if ([selected count] > 0) {
        [[BulkModifyHelper sharedHelper] editMilestone:selected window:self.view.window];
    }
}

- (IBAction)bulkModifyLabels:(id)sender {
    NSArray *selected;
    if ([[sender menu] supermenu] == _table.menu) {
        selected = [self selectedItemsForMenu];
    } else {
        selected = [self selectedItems];
    }
    
    if ([selected count] > 0) {
        [[BulkModifyHelper sharedHelper] editLabels:selected window:self.view.window];
    }
}

- (IBAction)bulkModifyAssignee:(id)sender {
    NSArray *selected;
    if ([[sender menu] supermenu] == _table.menu) {
        selected = [self selectedItemsForMenu];
    } else {
        selected = [self selectedItems];
    }
    
    if ([selected count] > 0) {
        [[BulkModifyHelper sharedHelper] editAssignees:selected window:self.view.window];
    }
}

- (IBAction)bulkModifyState:(id)sender {
    NSArray *selected;
    if ([[sender menu] supermenu] == _table.menu) {
        selected = [self selectedItemsForMenu];
    } else {
        selected = [self selectedItems];
    }
    
    if ([selected count] > 0) {
        [[BulkModifyHelper sharedHelper] editState:selected window:self.view.window];
    }
}

- (void)_makeColumns {
    _table.autosaveTableColumns = NO;
    
    if (!_tableColumns) {
        _tableColumns = [NSMutableArray new];
    } else {
        [_tableColumns removeAllObjects];
    }
    
    NSArray *oldCols = [_table.tableColumns copy];
    for (NSTableColumn *old in oldCols) {
        [_table removeTableColumn:old];
    }
    
    NSArray *columnSpecs = [[self class] columnSpecs];
    for (NSDictionary *columnSpec in columnSpecs) {
        NSString *columnIdentifier = columnSpec[@"identifier"];
        NSTableColumn *column = [[NSTableColumn alloc] initWithIdentifier:columnIdentifier];
        if (_upNextMode) {
            column.sortDescriptorPrototype = nil;
        } else if (columnSpec[@"sortDescriptor"]) {
            column.sortDescriptorPrototype = columnSpec[@"sortDescriptor"];
        } else {
            column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:columnIdentifier ascending:YES];
        }
        column.title = columnSpec[@"title"];
        column.width = [columnSpec[@"width"] doubleValue];
        column.minWidth = columnSpec[@"minWidth"] ? [columnSpec[@"minWidth"] doubleValue] : column.width;
        column.maxWidth = columnSpec[@"maxWidth"] ? [columnSpec[@"maxWidth"] doubleValue] : column.width;
        column.editable = [columnSpec[@"editable"] boolValue];
        if ([columnSpec[@"centered"] boolValue]) {
            column.headerCell.alignment = NSTextAlignmentCenter;
        }
        if (columnSpec[@"cellClass"]) {
            Class class = NSClassFromString(columnSpec[@"cellClass"]);
            column.dataCell = [class new];
        }
        if (columnSpec[@"titleFont"]) {
            column.headerCell.font = columnSpec[@"titleFont"];
        }
        NSCell *dataCell = column.dataCell;
        dataCell.formatter = columnSpec[@"formatter"];
        column.hidden = ![_defaultColumns containsObject:columnIdentifier];
        [_table addTableColumn:column];
        [_tableColumns addObject:column];
    }
    
    _table.autosaveTableColumns = YES;
    _table.autosaveName = _autosaveName;
}

- (void)resetColumns:(id)sender {
    _table.autosaveName = nil;
    [self _makeColumns];
    [self _makeColumnHeaderMenu];
    [_table sizeToFit];
    _table.autosaveName = self.autosaveName;
}

- (void)setAutosaveName:(NSString *)autosaveName {
    _autosaveName = [autosaveName copy];
    _table.autosaveName = _autosaveName;
}

- (void)setDefaultColumns:(NSSet *)defaultColumns {
    _defaultColumns = [defaultColumns copy];
    for (NSTableColumn *col in _tableColumns) {
        col.hidden = ![_defaultColumns containsObject:col.identifier];
    }
}

- (NSArray *)tableItems {
    return _items;
}

- (void)setTableItems:(NSArray *)tableItems {
    [self setTableItems:tableItems clearSelection:NO];
}

- (void)setTableItems:(NSArray *)tableItems clearSelection:(BOOL)clearSelection {
    [self _updateItems:tableItems clearSelection:clearSelection];
}

- (void)updateSingleItem:(Issue *)updatedItem {
    NSInteger idx = [_items indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger j, BOOL * _Nonnull stop) {
        return [[obj fullIdentifier] isEqualToString:[updatedItem fullIdentifier]];
    }];
    
    if (idx != NSNotFound) {
        DebugLog(@"Updating item at idx %td to %@", idx, updatedItem);
        NSSet *previouslySelectedIdentifiers = [self selectedItemIdentifiers];
        [_items replaceObjectAtIndex:idx withObject:updatedItem];
        [_table reloadData];
        [self selectItemsByIdentifiers:previouslySelectedIdentifiers];
    }
}

- (void)removeSingleItem:(Issue *)removeItem {
    NSInteger idx = [_items indexOfObjectPassingTest:^BOOL(id  _Nonnull obj, NSUInteger j, BOOL * _Nonnull stop) {
        return [[obj fullIdentifier] isEqualToString:[removeItem fullIdentifier]];
    }];
    
    if (idx != NSNotFound) {
        [_table beginUpdates];
        [_table removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:idx] withAnimation:NSTableViewAnimationEffectFade];
        [_items removeObjectAtIndex:idx];
        [_table endUpdates];
        _animationInProgress = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _animationInProgress = NO;
            if (_afterTableAnimation) {
                NSInvocation *iv = _afterTableAnimation;
                _afterTableAnimation = nil;
                [iv invoke];
            }
        });
    }
}

- (void)_sortItems {
    NSArray *sortDescriptors = _table.sortDescriptors;
    if (_upNextMode) {
        sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"upNextPriority" ascending:YES]];
    }
    NSSortDescriptor *stability = [NSSortDescriptor sortDescriptorWithKey:@"fullIdentifier" ascending:YES];
    if (!sortDescriptors) {
        sortDescriptors = @[stability];
    } else {
        sortDescriptors = [sortDescriptors arrayByAddingObject:stability];
    }
    @try {
        [_items sortUsingDescriptors:sortDescriptors];
    } @catch (id exc) {
        // This can happen if we had some sort descriptors saved in user defaults, but then removed those properties on the model.
        ErrLog(@"Error sorting items with descriptors %@: %@", sortDescriptors, exc);
        sortDescriptors = @[stability];
        [_items sortUsingDescriptors:sortDescriptors];
        _table.sortDescriptors = sortDescriptors;
    }
}

- (void)_updateItems:(NSArray *)items clearSelection:(BOOL)clearSelection {
    if (_animationInProgress) {
        NSInvocation *iv = _afterTableAnimation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:_cmd]];
        iv.target = self;
        iv.selector = _cmd;
        id arg2 = items;
        BOOL arg3 = clearSelection;
        [iv setArgument:&arg2 atIndex:2];
        [iv setArgument:&arg3 atIndex:3];
        [iv retainArguments];
        
        return;
    } else {
        _afterTableAnimation = nil;
    }
    
    NSSet *previouslySelectedIdentifiers = clearSelection ? nil : [self selectedItemIdentifiers];
    _items = [items mutableCopy];
    
    [self _sortItems];
    [_table reloadData];
    [self selectItemsByIdentifiers:previouslySelectedIdentifiers];
    [self updateEmptyState];
}

- (NSString *)tabSeparatedHeader {
    NSMutableString *str = [NSMutableString new];
    NSUInteger i = 0;
    NSArray *cols = _tableColumns;
    NSUInteger maxCols = [cols count];
    for (NSTableColumn *column in cols) {
        if ([column.identifier isEqualToString:@"read"]) {
            i++;
            continue;
        }
        [str appendString:column.title];
        i++;
        if (i < maxCols) {
            [str appendString:@"\t"];
        } else {
            [str appendString:@"\r"];
        }
    }
    return str;
}

- (NSString *)tabSeparatedRowForProblem:(id)problem {
    NSMutableString *str = [NSMutableString new];
    NSUInteger i = 0;
    NSArray *cols = _tableColumns;
    NSUInteger maxCols = [cols count];
    for (NSTableColumn *column in cols) {
        NSString *value = @"--";
        if ([column.identifier isEqualToString:@"read"]) {
            i++;
            continue;
        } else {
            id obj = [problem valueForKeyPath:column.identifier];
            if ([obj isKindOfClass:[NSDate class]]) {
                value = [obj longUserInterfaceString];
            } else {
                value = [obj description];
            }
            value = value ?: @"--";
        }
        [str appendString:value];
        i++;
        if (i < maxCols) {
            [str appendString:@"\t"];
        } else {
            [str appendString:@"\r"];
        }
    }
    return str;
}

- (IBAction)copy:(id)sender {
    NSArray *selected = [self selectedItems];
    if ([selected count] == 0) {
        return;
    }

    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    
    NSMutableString *str = [NSMutableString new];
    [str appendString:[self tabSeparatedHeader]];
    for (id item in selected) {
        [str appendString:[self tabSeparatedRowForProblem:item]];
    }
    [pb clearContents];
    [pb writeObjects:@[str]];
}

- (void)copyNumbers:(NSArray *)selected {
    [NSString copyIssueIdentifiers:[selected arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }] toPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)copyNumbersAndTitles:(NSArray *)selected {
    [NSString copyIssueIdentifiers:[selected arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }] withTitles:[selected arrayByMappingObjects:^id(id obj) {
        return [obj title];
    }] toPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)copyIssueNumber:(id)sender {
    NSArray *selected = [self selectedItems];
    [self copyNumbers:selected];
}

- (IBAction)copyIssueNumberWithTitle:(id)sender {
    NSArray *selected = [self selectedItems];
    [self copyNumbersAndTitles:selected];
}

- (IBAction)copyIssueGitHubURL:(id)sender {
    NSArray *selected = [self selectedItems];
    [[[selected firstObject] fullIdentifier] copyIssueGitHubURLToPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)openDocument:(id)sender {
    NSArray *selected = [self selectedItems];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }];
    [[IssueDocumentController sharedDocumentController] openIssuesWithIdentifiers:identifiers];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(copyIssueNumber:)
        || item.action == @selector(copyIssueNumberWithTitle:)
        || item.action == @selector(openDocument:)) {
        return [[self selectedItems] count] > 0;
    }
    if (item.action == @selector(copyIssueGitHubURL:)) {
        return [[self selectedItems] count] == 1;
    }
    if (item.action == @selector(toggleUpNext:)) {
        item.title = _upNextMode ? NSLocalizedString(@"Remove from Up Next", nil) : NSLocalizedString(@"Add to Up Next", nil);
        return [[self selectedItems] count] > 0;
    }
    if (item.action == @selector(bulkModifyState:)
        || item.action == @selector(bulkModifyLabels:)
        || item.action == @selector(bulkModifyAssignee:)
        || item.action == @selector(bulkModifyMilestone:))
    {
        return [[self selectedItems] count] > 0 || [[self selectedItemsForMenu] count] > 0;
    }
    return YES;
}

- (void)setUpNextMode:(BOOL)mode {
    if (_upNextMode != mode) {
        _upNextMode = mode;
        [self _makeColumns];
        [self _makeColumnHeaderMenu];
        [self _sortItems];
    }
}

- (void)setEmptyPlaceholderViewController:(NSViewController *)emptyPlaceholderViewController {
    if (_emptyPlaceholderViewController == emptyPlaceholderViewController)
        return;
    
    if (_emptyPlaceholderViewController) {
        if ([_emptyPlaceholderViewController isViewLoaded]) {
            [_emptyPlaceholderViewController.view removeFromSuperview];
        }
    }
    
    _emptyPlaceholderViewController = emptyPlaceholderViewController;
    
    [self updateEmptyState];
}

- (void)updateEmptyState {
    if (_items.count == 0) {
        if (_emptyPlaceholderViewController) {
            if ([_emptyPlaceholderViewController.view superview] != _table) {
                _emptyPlaceholderViewController.view.frame = _table.bounds;
                _emptyPlaceholderViewController.view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
                _table.autoresizesSubviews = YES;
                [_table addSubview:_emptyPlaceholderViewController.view];
            }
        }
    } else {
        if (_emptyPlaceholderViewController && [_emptyPlaceholderViewController isViewLoaded]) {
            [_emptyPlaceholderViewController.view removeFromSuperview];
        }
    }
    
    _table.usesAlternatingRowBackgroundColors = [self usesAlternatingRowBackgroundColors] && (_items.count > 0 || _emptyPlaceholderViewController == nil);
}

- (BOOL)usesAlternatingRowBackgroundColors {
    return YES;
}

#pragma mark - NSTableViewDataSource & NSTableViewDelegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_items count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    Issue *item = _items[row];
    if ([tableColumn.identifier isEqualToString:@"labels"]) {
        return item.labels; // don't ever return a @"--" for labels.
    }
    
    id result = [item valueForKeyPath:tableColumn.identifier] ?: @"--";
    return result;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    
}

- (void)selectSomething {
    NSIndexSet *selected = [_table selectedRowIndexes];
    if ([selected count] == 0 && _items.count != 0) {
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        if ([self.delegate respondsToSelector:@selector(issueTableController:didChangeSelection:userInitiated:)]) {
            [self.delegate issueTableController:self didChangeSelection:[self selectedProblemSnapshots] userInitiated:NO];
        }
    }
}

- (NSSet *)selectedItemIdentifiers {
    return [NSSet setWithArray:[[self selectedItems] arrayByMappingObjects:^id(id obj) {
        return [obj identifier];
    }]];
}

- (void)selectItemsByIdentifiers:(NSSet *)identifiers {
    NSIndexSet *selected = [_items indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [identifiers containsObject:[obj identifier]];
    }];
    [_table selectRowIndexes:selected byExtendingSelection:NO];
    if ([self.delegate respondsToSelector:@selector(issueTableController:didChangeSelection:userInitiated:)]) {
        [self.delegate issueTableController:self didChangeSelection:[self selectedProblemSnapshots] userInitiated:NO];
    }
}

- (NSArray <Issue*> *)selectedProblemSnapshots {
    return [self selectedItems];
}

- (NSArray *)selectedItems {
    NSIndexSet *selected = [_table selectedRowIndexes];
    return [_items objectsAtIndexes:selected];
}

- (void)selectItems:(NSArray *)items {
    NSSet *set = [NSSet setWithArray:items];
    NSIndexSet *selected = [_items indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return [set containsObject:obj];
    }];
    [_table selectRowIndexes:selected byExtendingSelection:NO];
    if ([self.delegate respondsToSelector:@selector(issueTableController:didChangeSelection:userInitiated:)]) {
        [self.delegate issueTableController:self didChangeSelection:[self selectedProblemSnapshots] userInitiated:NO];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    if ([self.delegate respondsToSelector:@selector(issueTableController:didChangeSelection:userInitiated:)]) {
        [self.delegate issueTableController:self didChangeSelection:[self selectedProblemSnapshots] userInitiated:YES];
    }
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    if (self.loading) {
        return; // We cannot sort during a load
    }
    
    NSArray *selected = [self selectedItems];
    [self _sortItems];
    [_table reloadData];
    [self selectItems:selected];
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    NSArray *items = [_items objectsAtIndexes:rowIndexes];
    [NSString copyIssueIdentifiers:[items arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }] toPasteboard:pboard];
    
    return YES;
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes
{
    CGPoint dragLoc = session.draggingLocation;
    NSImage *dragImage = [NSImage imageNamed:@"AppIcon"];
    CGSize imageSize = { 32.0, 32.0 };
    CGFloat xOff = imageSize.width / 2.0;
    if (rowIndexes.count > 1) {
        NSDictionary *attr = @{ NSFontAttributeName : [NSFont boldSystemFontOfSize:11.0],
                                NSForegroundColorAttributeName : [NSColor whiteColor] };
        NSString *pillStr = [NSString localizedStringWithFormat:@"%tu", rowIndexes.count];
        
        CGSize strSize = [pillStr sizeWithAttributes:attr];
        
        CGSize pillSize = CGSizeMake(strSize.width + 14.0, strSize.height + 2.0);
        
        CGSize compositeSize = CGSizeMake(imageSize.width + pillSize.width - (pillSize.height / 2.0), imageSize.height);
        NSImage *composite = [[NSImage alloc] initWithSize:compositeSize];
        
        [composite lockFocus];
        
        [[NSColor clearColor] set];
        NSRectFill(CGRectMake(0, 0, compositeSize.width, compositeSize.height));
        
        [dragImage drawInRect:CGRectMake(0, 0, imageSize.width, imageSize.height)];
        
        CGRect pathRect = CGRectMake(compositeSize.width - pillSize.width - 1.0, 1.0, pillSize.width - 2.0, pillSize.height - 2.0);
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:pathRect xRadius:(pillSize.height - 2.0) / 2.0 yRadius:(pillSize.height - 2.0) / 2.0];
        [[NSColor whiteColor] setStroke];
        [[NSColor redColor] setFill];
        path.lineWidth = 1.0;
        [path fill];
        [path stroke];
        
        [pillStr drawInRect:CGRectMake(CGRectGetMinX(pathRect) + (CGRectGetWidth(pathRect) - strSize.width) / 2.0,
                                       CGRectGetMinY(pathRect) + (CGRectGetHeight(pathRect) - strSize.height) / 2.0,
                                       strSize.width, strSize.height) withAttributes:attr];
        
        [composite unlockFocus];
        dragImage = composite;
        imageSize = compositeSize;
        // leave xOff alone, we want the icon to be centered under the cursor, but not the count pill.
    }
    
    CGRect imageRect = CGRectMake(dragLoc.x - xOff,
                                 dragLoc.y - imageSize.height / 2.0,
                                 imageSize.width,
                                 imageSize.height);

    
    
    [session enumerateDraggingItemsWithOptions:0
                                       forView:nil
                                       classes:@[[NSPasteboardItem class]]
                                 searchOptions:@{}
                                    usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop)
     {
         [draggingItem setDraggingFrame:imageRect contents:dragImage];
         *stop = YES;
     }];
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation
{
    if (operation == NSDragOperationDelete) {
        NSIndexSet *selectedIdxs = [_table selectedRowIndexes];
        NSArray *selected = [self selectedItems];
        if ([_delegate respondsToSelector:@selector(issueTableController:deleteItems:)] && [_delegate issueTableController:self deleteItems:selected]) {
            if ([_delegate issueTableController:self deleteItems:selected]) {
                [_items removeObjectsAtIndexes:selectedIdxs];
                [_table reloadData];
            }
        }
    }
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pb = [info draggingPasteboard];
    NSArray *issueIdentifiers = [NSString readIssueIdentifiersFromPasteboard:pb];
    
    if ([issueIdentifiers count] == 0) {
        return NSDragOperationNone;
    }
    
    if (operation != NSTableViewDropAbove) {
        [aTableView setDropRow:row dropOperation:NSTableViewDropAbove];
    }
    
    if ([info draggingSource] == _table) {
        if (_upNextMode && [_delegate respondsToSelector:@selector(issueTableController:didReorderItems:aboveItemAtIndex:)]) {
            return NSDragOperationGeneric;
        } else {
            return NSDragOperationNone;
        }
    }
    
    if (![_delegate respondsToSelector:@selector(issueTableController:shouldAcceptDrop:)]) {
        return NSDragOperationNone;
    }
    
    if ([_delegate issueTableController:self shouldAcceptDrop:issueIdentifiers]) {
        return NSDragOperationCopy;
    } else {
        return NSDragOperationNone;
    }
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    NSPasteboard *pb = [info draggingPasteboard];
    NSArray *issueIdentifiers = [NSString readIssueIdentifiersFromPasteboard:pb];
    
    if ([issueIdentifiers count] == 0) {
        return NO;
    }
    
    if ([info draggingSource] == _table) {
        // it's a re-order
        if ([_delegate respondsToSelector:@selector(issueTableController:didReorderItems:aboveItemAtIndex:)]) {
            NSSet *identifierSet = [NSSet setWithArray:issueIdentifiers];
            NSIndexSet *movedIdxs = [_items indexesOfObjectsPassingTest:^BOOL(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                return [identifierSet containsObject:[obj fullIdentifier]];
            }];
            NSArray *moved = [_items objectsAtIndexes:movedIdxs];
            Issue *context = row >= 0 && row < _items.count ? _items[row] : nil;
            [_items moveItemsAtIndexes:movedIdxs toIndex:row];
            NSInteger dstLoc = context ? [_items indexOfObjectIdenticalTo:context] : _items.count;
            [self.table reloadData];
            [_delegate issueTableController:self didReorderItems:moved aboveItemAtIndex:dstLoc];
            [self selectItems:moved];
            return YES;
        }
    } else {
        // add new items from external source
        if ([_delegate respondsToSelector:@selector(issueTableController:didAcceptDrop:aboveItemAtIndex:)]) {
            [_delegate issueTableController:self didAcceptDrop:issueIdentifiers aboveItemAtIndex:row];
            return YES;
        }
    }
    
    return NO;
}

- (void)tableViewDoubleClicked:(id)sender {
    NSInteger row = [_table clickedRow];
    if (row != NSNotFound && row < [_items count]) {
        Issue *item = _items[row];
        [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:item.fullIdentifier];
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    [cell setFont:[NSFont systemFontOfSize:12.0]];
}

- (NSIndexSet *)tableView:(NSTableView *)tableView selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes {
    if (self.loading) {
        // Can't change selection during loading
        return [tableView selectedRowIndexes];
    } else {
        return proposedSelectionIndexes;
    }
}

- (NSString *)tableView:(NSTableView *)tableView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (tableColumn.hidden) return nil;
    else return [[tableView preparedCellAtColumn:[tableView columnWithIdentifier:tableColumn.identifier] row:row] stringValue];
#pragma diagnostic pop
}

- (BOOL)tableView:(NSTableView *)tableView handleKeyPressEvent:(NSEvent *)event {
    if ([event isDelete] && [_delegate respondsToSelector:@selector(issueTableController:deleteItems:)]) {
        NSIndexSet *selectedIdxs = [_table selectedRowIndexes];
        NSArray *selected = [self selectedItems];
        if ([_delegate issueTableController:self deleteItems:selected]) {
            [_items removeObjectsAtIndexes:selectedIdxs];
            [_table reloadData];
        }
        return YES;
    } else if ([event isReturn]) {
        [self openDocument:tableView];
        return YES;
    }
    return NO;
}

@end

@implementation ProblemTableView

@dynamic delegate;

- (void)keyDown:(NSEvent *)theEvent {
    id<ProblemTableViewDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(tableView:handleKeyPressEvent:)]) {
        if ([delegate tableView:self handleKeyPressEvent:theEvent]) {
            return;
        }
    }
    [super keyDown:theEvent];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL became = [super becomeFirstResponder];
    
    if (became) {
        NSIndexSet *selected = [self selectedRowIndexes];
        if ([selected count] == 0 && self.numberOfRows > 0) {
            [self selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:0];
        }
    }
    
    return became;
}

@end

@interface ReadIndicatorCell : NSTextFieldCell

@end

@implementation ReadIndicatorCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    BOOL unread = [[self objectValue] boolValue];
    
    if (unread) {
        BOOL highlighted = [self isHighlighted];
        
        CGRect rect = CGRectMake(0, 0, 8.0, 8.0);
        rect = CenteredRectInRect(cellFrame, rect);
        rect = IntegralRect(rect);
        
        if (controlView.window.screen.backingScaleFactor > 1.9) {
            rect.origin.x += 0.5;
        }
        
        NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:rect];
        
        if (highlighted) {
            [[NSColor whiteColor] setFill];
        } else {
            [[NSColor extras_controlBlue] setFill];
        }
        
        [path fill];
    }
}

@end

@interface LabelsCell : NSTextFieldCell

@end

@implementation LabelsCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    NSArray *labels = [self objectValue];
    
    NSColor *background = [self backgroundColor];
    if ([self isHighlighted]) {
        background = [self highlightColorWithFrame:cellFrame inView:controlView];
    }
    
    [LabelsView drawLabels:labels inRect:cellFrame highlighted:[self isHighlighted] backgroundColor:background];
}

- (NSRect)expansionFrameWithFrame:(NSRect)cellFrame inView:(NSView *)view {
    CGSize size = [LabelsView sizeLabels:[self objectValue]];
    cellFrame.size = size;
    return cellFrame;
}

@end

@implementation MultipleAssigneesFormatter

- (nullable NSString *)stringForObjectValue:(id)obj {
    if ([obj isKindOfClass:[NSArray class]]) {
        return [obj componentsJoinedByString:@", "];
    } else {
        return [obj description];
    }
}

@end

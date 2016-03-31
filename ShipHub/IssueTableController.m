//
//  ProblemTableController.m
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "IssueTableController.h"

#import "IssueDocumentController.h"

#import "DataStore.h"
#import "Extras.h"
#import "Issue.h"
#import "IssueIdentifier.h"

@protocol ProblemTableViewDelegate <NSTableViewDelegate>
@optional
- (BOOL)tableView:(NSTableView *)tableView handleKeyPressEvent:(NSEvent *)event; // return YES if delegate handled, NO if table should handle by itself

@end

@interface ProblemTableView : NSTableView

@property id<ProblemTableViewDelegate> delegate;

@end

@interface ProblemTableItem : NSObject

@property (strong) id<IssueTableItem> info;
@property (strong) Issue *issue;

- (id<NSCopying>)identifier;

+ (instancetype)itemWithInfo:(id<IssueTableItem>)info;

@end

@interface IssueTableController () <ProblemTableViewDelegate, NSTableViewDataSource, NSMenuDelegate>

@property (strong) IBOutlet NSTableView *table;

@property (strong) NSMutableArray *tableColumns; // NSTableView .tableColumns property doesn't preserve order, and we want this in our order.

@property (strong) NSMutableArray *items;
@property (strong) NSMutableDictionary *itemLookup;
@property (strong) NSMutableDictionary *problemCache;
@property BOOL shouldReloadData;
@property BOOL loading;
@property NSInteger loadGeneration;

@end

@implementation IssueTableController

- (void)commonInit {
    _items = [NSMutableArray array];
    _itemLookup = [NSMutableDictionary dictionary];
    _problemCache = [NSMutableDictionary dictionary];
    _defaultColumns = [NSSet setWithArray:@[@"issue.number", @"issue.title", @"issue.assignee.login", @"issue.repo.fullName"]];
}

- (id)init {
    return [self initWithNibName:@"IssueTableController" bundle:[NSBundle bundleForClass:[self class]]];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
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

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _table.doubleAction = @selector(tableViewDoubleClicked:);
    [_table registerForDraggedTypes:@[(__bridge NSString *)kUTTypeURL]];
    
    NSMenu *menu = [[NSMenu alloc] init];
    menu.delegate = self;
    [menu addItemWithTitle:NSLocalizedString(@"Open", nil) action:@selector(openFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy URL", nil) action:@selector(copyURLFromMenu:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Mark As Read", nil) action:@selector(markAsReadFromMenu:) keyEquivalent:@""];
    _table.menu = menu;
}

- (void)viewDidAppear {
    [super viewDidAppear];
    
    _table.autosaveTableColumns = YES;
    _table.autosaveName = _autosaveName;
    
    [self _makeColumns];
    [self _makeColumnHeaderMenu];
}

static NSString *const IssuePopupIdentifier = @"info.issuePopupIndex";

+ (NSArray *)columnSpecs {
    static NSArray *specs;
    if (!specs) {
        specs = @[
                  @{ @"identifier" : IssuePopupIdentifier,
                     @"title" : NSLocalizedString(@"Action", nil),
                     @"width" : @90,
                     @"fixed" : @YES,
                     @"editable" : @YES },
                  
#if !INCOMPLETE
                  @{ @"identifier" : @"issue.read",
                     @"title" : NSLocalizedString(@"•", nil),
                     @"menuTitle" : NSLocalizedString(@"Unread", nil),
                     @"formatter" : [BooleanDotFormatter new],
                     @"width" : @20,
                     @"maxWidth" : @20,
                     @"minWidth" : @20,
                     @"centered" : @YES,
                     @"cellClass" : @"ReadIndicatorCell",
                     @"titleFont" : [NSFont boldSystemFontOfSize:12.0] },
#endif
                  
                  @{ @"identifier" : @"issue.number",
                     @"title" : NSLocalizedString(@"#", nil),
                     @"formatter" : [NSNumberFormatter positiveAndNegativeIntegerFormatter],
                     @"width" : @46,
                     @"maxWidth" : @46,
                     @"minWidth" : @46 },
                  
                  @{ @"identifier" : @"info.issueFullIdentifier",
                     @"title" : NSLocalizedString(@"Path", nil),
                     @"width" : @180,
                     @"maxWidth" : @260,
                     @"minWidth" : @60 },
                  
                  @{ @"identifier" : @"issue.title",
                     @"title" : NSLocalizedString(@"Title", nil),
                     @"width" : @271,
                     @"minWidth" : @100,
                     @"maxWidth" : @10000 },
                  
                  @{ @"identifier" : @"issue.assignee.login",
                     @"title" : NSLocalizedString(@"Assignee", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"issue.originator.login",
                     @"title" : NSLocalizedString(@"Originator", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"issue.closedBy.login",
                     @"title" : NSLocalizedString(@"Resolver", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @200 },
                  
                  @{ @"identifier" : @"issue.repository.fullName",
                     @"title" : NSLocalizedString(@"Repo", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @250 },
                  
                  @{ @"identifier" : @"issue.milestone.title",
                     @"title" : NSLocalizedString(@"Milestone", nil),
                     @"width" : @160,
                     @"minWidth" : @130,
                     @"maxWidth" : @250 },
                  
                  @{ @"identifier" : @"issue.closed",
                     @"title" : NSLocalizedString(@"Closed", nil),
                     @"width" : @130,
                     @"minWidth" : @100,
                     @"maxWidth" : @150 },
                  
                  @{ @"identifier" : @"issue.updatedAt",
                     @"title" : NSLocalizedString(@"Modified", nil),
                     @"formatter" : [NSDateFormatter shortDateAndTimeFormatter],
                     @"width" : @130 },
                  
                  @{ @"identifier" : @"issue.createdAt",
                     @"formatter" : [NSDateFormatter shortDateAndTimeFormatter],
                     @"title" : NSLocalizedString(@"Created", nil),
                     @"width" : @130 },
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
        if ([[col identifier] isEqualToString:IssuePopupIdentifier]) {
            continue;
        }
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
    // FIXME: Hook up
    NSArray *selected = [self selectedItemsForMenu];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [[obj issue] fullIdentifier];
    }];
    [[IssueDocumentController sharedDocumentController] openIssuesWithIdentifiers:identifiers];
}

- (void)copyURLFromMenu:(id)sender {
    NSArray *selected = [self selectedItemsForMenu];
    [self copyURLs:selected];
}

- (void)markAsReadFromMenu:(id)sender {
    // FIXME: Hook up
#if !INCOMPLETE
    NSArray *selected = [self selectedItemsForMenu];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [[obj problem] identifier];
    }];
    [[DataStore activeStore] markAsRead:identifiers];
#endif
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
        column.sortDescriptorPrototype = [NSSortDescriptor sortDescriptorWithKey:columnIdentifier ascending:YES];
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
        if ([columnIdentifier isEqualToString:IssuePopupIdentifier]) {
            column.title = _popupColumnTitle ?: column.title;
            column.hidden = [_popupItems count] == 0;
            NSPopUpButtonCell *cell = [[NSPopUpButtonCell alloc] init];
            cell.controlSize = NSMiniControlSize;
            cell.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
            [cell removeAllItems];
            if (_popupItems) {
                [cell addItemsWithTitles:_popupItems];
            }
            column.dataCell = cell;
        } else {
            column.hidden = ![_defaultColumns containsObject:columnIdentifier];
        }
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

- (void)setPopupItems:(NSArray *)popupItems {
    _popupItems = [popupItems copy];
    NSTableColumn *popCol = [_table tableColumnWithIdentifier:IssuePopupIdentifier];
    popCol.hidden = [_popupItems count] == 0;
    NSPopUpButtonCell *cell = popCol.dataCell;
    [cell removeAllItems];
    [cell addItemsWithTitles:popupItems];
    [_table reloadDataForRowIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)] columnIndexes:[NSIndexSet indexSetWithIndex:[_table columnWithIdentifier:IssuePopupIdentifier]]];
}

- (void)setPopupColumnTitle:(NSString *)popupColumnTitle {
    _popupColumnTitle = [popupColumnTitle copy];
    NSTableColumn *popCol = [_table tableColumnWithIdentifier:IssuePopupIdentifier];
    popCol.title = popupColumnTitle;
}

- (void)setDefaultColumns:(NSSet *)defaultColumns {
    _defaultColumns = [defaultColumns copy];
    for (NSTableColumn *col in _tableColumns) {
        col.hidden = ![_defaultColumns containsObject:col.identifier];
    }
}

- (void)setTableItems:(NSArray *)tableItems {
    [self setTableItems:tableItems clearSelection:NO];
}

- (void)setTableItems:(NSArray *)tableItems clearSelection:(BOOL)clearSelection {
    _tableItems = tableItems;
    [self _updateItemsAndClearSelection:clearSelection];
}

- (void)_updateItemsAndClearSelection:(BOOL)clearSelection {
    NSSet *previouslySelectedIdentifiers = clearSelection ? nil : [self selectedItemIdentifiers];

    [_items removeAllObjects];
    [_itemLookup removeAllObjects];
    // Create item for each tableItem
    for (id<IssueTableItem> tableItem in _tableItems) {
        id identifier = tableItem.issueFullIdentifier;
        ProblemTableItem *item = [ProblemTableItem itemWithInfo:tableItem];
        [_items addObject:item];
        if (_itemLookup[identifier]) {
            [_itemLookup[identifier] addObject:item];
        } else {
            _itemLookup[identifier] = [NSMutableArray arrayWithObject:item];
        }
    }
    
    // Compute set of all problemIdentifiers
    NSMutableSet *knownIdentifiers = [NSMutableSet set];
    for (ProblemTableItem *item in _items) {
        [knownIdentifiers addObject:item.info.issueFullIdentifier];
    }
    
    // Filter out items from cache that are no longer referenced
    [_problemCache filterUsingBlock:^BOOL(id<NSCopying> key, id value) {
        return [knownIdentifiers containsObject:key];
    }];
    
    // Populate items's problems for anything already in cache.
    NSMutableSet *loadThese = [NSMutableSet set];
    for (ProblemTableItem *item in _items) {
        id problemIdentifier = item.info.issueFullIdentifier;
        Issue *snapshot = nil;
        if ([item.info respondsToSelector:@selector(issue)]) {
            snapshot = item.info.issue;
        }
        if (!snapshot) {
            snapshot = _problemCache[problemIdentifier];
            [loadThese addObject:problemIdentifier];
        }
        item.issue = snapshot;
    }
    
    // Load any needed problems from the store
    self.loading = YES;
    NSInteger loadGeneration = ++_loadGeneration;
    
    [[DataStore activeStore] issuesMatchingPredicate:[NSPredicate predicateWithFormat:@"fullIdentifier IN %@", loadThese] completion:^(NSArray<Issue *> *issues, NSError *error) {
        if (_loadGeneration != loadGeneration) {
            return;
        }

        for (Issue *i in issues) {
            _problemCache[i.fullIdentifier] = i;
            NSArray *items = _itemLookup[i.fullIdentifier];
            BOOL shouldReload = !self.shouldReloadData;
            self.shouldReloadData = YES;
            
            //            NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
            for (ProblemTableItem *item in items) {
                item.issue = i;
                //                NSUInteger idx = [_items indexOfObjectIdenticalTo:item];
                //                [indexes addIndex:idx];
            }
            
            if (shouldReload) {
                // This is because NSTableView is busted and will drop more than 13 successive reloadDataForRowIndexes called within the same turn of the runloop.
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_table reloadData];
                    self.shouldReloadData = NO;
                });
            }
        }
        
        self.loading = NO;
        if (_table.sortDescriptors) {
            [_items sortUsingDescriptors:_table.sortDescriptors];
            [_table reloadData];
        }
        [self selectItemsByIdentifiers:previouslySelectedIdentifiers];
    }];
    
    [_table reloadData];
}
         
- (void)reloadProblemsAndClearSelection:(BOOL)invalidateSelection {
    [_problemCache removeAllObjects];
    [self _updateItemsAndClearSelection:invalidateSelection];
}

- (void)reloadProblems {
    [self reloadProblemsAndClearSelection:NO];
}

- (NSString *)tabSeparatedHeader {
    NSMutableString *str = [NSMutableString new];
    NSUInteger i = 0;
    NSArray *cols = _tableColumns;
    NSUInteger maxCols = [cols count];
    for (NSTableColumn *column in cols) {
        if ([column.identifier isEqualToString:IssuePopupIdentifier] && column.hidden) {
            i++;
            continue;
        } else if ([column.identifier isEqualToString:@"issue.read"]) {
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
        if ([column.identifier isEqualToString:IssuePopupIdentifier]) {
            if (column.hidden) {
                i++;
                continue;
            } else {
                value = _popupItems[[[problem valueForKeyPath:column.identifier] unsignedIntegerValue]];
            }
        } else if ([column.identifier isEqualToString:@"issue.read"]) {
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

- (void)copyURLs:(NSArray *)selected {
    // FIXME: Hook up
#if !INCOMPLETE
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    if ([selected count] == 1) {
        id<ProblemSnapshot> item = [[selected firstObject] problem];
        NSString *urlAndTitle = [Problem URLWithIdentifier:item.identifier andTitle:item.title];
        NSURL *url = [Problem URLWithIdentifier:item.identifier];
        [pb clearContents];
        [pb writeURL:url string:urlAndTitle];
    } else if ([selected count] > 1) {
        NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
            return [[obj info] problemIdentifier];
        }];
        NSOrderedSet *identifierSet = [NSOrderedSet orderedSetWithArray:identifiers];
        [pb clearContents];
        NSURL *URL = [Problem URLWithIdentifiers:[identifierSet array]];
        [pb writeURL:URL];
    }
#endif
}

- (IBAction)copyURL:(id)sender {
    NSArray *selected = [self selectedItems];
    [self copyURLs:selected];
}

- (IBAction)openDocument:(id)sender {
    NSArray *selected = [self selectedItems];
    NSArray *identifiers = [selected arrayByMappingObjects:^id(id obj) {
        return [[obj issue] fullIdentifier];
    }];
    [[IssueDocumentController sharedDocumentController] openIssuesWithIdentifiers:identifiers];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if (item.action == @selector(copyURL:)
        || item.action == @selector(openDocument:)) {
        return [[self selectedItems] count] > 0;
    }
    return YES;
}

#pragma mark - NSTableViewDataSource & NSTableViewDelegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_items count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    ProblemTableItem *item = _items[row];
    id result = [item valueForKeyPath:tableColumn.identifier] ?: @"--";
    return result;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (![tableColumn.identifier isEqualToString:IssuePopupIdentifier]) {
        return;
    }
    
    ProblemTableItem *item = _items[row];
    NSNumber *idx = object;
    [_delegate issueTableController:self item:item.info popupSelectedItemAtIndex:[idx integerValue]];
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
}

- (NSArray <Issue*> *)selectedProblemSnapshots {
    return [[self selectedItems] arrayByMappingObjects:^id(id obj) {
        return [obj issue];
    }];
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
}

- (void)tableView:(NSTableView *)tableView sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    if (self.loading) {
        return; // We cannot sort during a load
    }
    
    NSArray *selected = [self selectedItems];
    [_items sortUsingDescriptors:tableView.sortDescriptors];
    [_table reloadData];
    [self selectItems:selected];
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
    // FIXME: Hook up
#if !INCOMPLETE
    NSArray *items = [_items objectsAtIndexes:rowIndexes];
    NSArray *identifiers = [items arrayByMappingObjects:^id(ProblemTableItem *obj) {
        return obj.info.problemIdentifier;
    }];
    
    [pboard writeURL:[Problem URLWithIdentifiers:identifiers]];
#endif
    
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    // FIXME: Hook up
#if !INCOMPLETE
    NSPasteboard *pb = [info draggingPasteboard];
    NSArray *URLs = [pb readObjectsForClasses:@[[NSURL class]] options:nil];
    
    if ([URLs count] != 1) {
        return NSDragOperationNone;
    }
    
    NSNumber *identifier = [Problem identifierFromURL:[URLs lastObject]];
    if (identifier && [_delegate respondsToSelector:@selector(issueTableController:shouldAcceptDrag:)] &&[_delegate issueTableController:self shouldAcceptDrag:identifier]) {
        return NSDragOperationLink;
    } else {
        return NSDragOperationNone;
    }
#else
    return NSDragOperationNone;
#endif
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    // FIXME: Hook up
#if !INCOMPLETE
    NSPasteboard *pb = [info draggingPasteboard];
    NSArray *URLs = [pb readObjectsForClasses:@[[NSURL class]] options:nil];
    
    NSNumber *identifier = [Problem identifierFromURL:[URLs firstObject]];
    if (identifier && [_delegate respondsToSelector:@selector(issueTableController:didAcceptDrag:)]) {
        return [_delegate issueTableController:self didAcceptDrag:identifier];
    }
    
    return NO;
#else
    return NO;
#endif
}

- (void)tableViewDoubleClicked:(id)sender {
    NSInteger row = [_table clickedRow];
    if (row != NSNotFound && row < [_items count]) {
        ProblemTableItem *item = _items[row];
        
        [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:item.info.issueFullIdentifier];
    }
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    if (![tableColumn.identifier isEqualToString:IssuePopupIdentifier]) {
        [cell setFont:[NSFont systemFontOfSize:12.0]];
    }
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
    if ([event isDelete] && [_delegate respondsToSelector:@selector(issueTableController:deleteItem:)]) {
        NSArray *selected = [self selectedItems];
        BOOL deletedAny = NO;
        for (ProblemTableItem *item in selected) {
            if ([_delegate issueTableController:self deleteItem:item.info]) {
                [_items removeObjectIdenticalTo:item];
                deletedAny = YES;
            }
        }
        if (deletedAny) {
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

@implementation ProblemTableItem
         
+ (instancetype)itemWithInfo:(id<IssueTableItem>)info {
    ProblemTableItem *item = [[self alloc] init];
    item.info = info;
    return item;
}

- (id<NSCopying>)identifier {
    return [_info identifier];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> info: %@ problem: %@", NSStringFromClass([self class]), self, self.info, self.issue];
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
    BOOL read = [[self objectValue] boolValue];
    
    if (!read) {
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

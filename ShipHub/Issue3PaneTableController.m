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
#import "Issue.h"
#import "IssueTableControllerPrivate.h"
#import "FilterButton.h"

#import <objc/runtime.h>

@protocol CompactIssueTableDelegate <ProblemTableViewDelegate>

@end

@interface CompactIssueTable : ProblemTableView

@property (weak) id<CompactIssueTableDelegate> delegate;

@end

@interface CompactIssueTableHeaderView : NSTableHeaderView

@property FilterButton *sortButton;

@end

@interface CompactIssueTableCornerView : NSView

@end

@interface Issue3PaneTableController ()

@property NSMutableArray *reuseQueue;
@property CompactIssueTableHeaderView *header;
@property CompactIssueTableCornerView *corner;

@end

@implementation Issue3PaneTableController

@dynamic delegate;

+ (Class)tableClass {
    return [CompactIssueTable class];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CompactIssueTableHeaderView *header = _header = [[CompactIssueTableHeaderView alloc] initWithFrame:CGRectMake(0, 0, 300.0, 19.0)];
    CompactIssueTableCornerView *corner = _corner = [[CompactIssueTableCornerView alloc] initWithFrame:CGRectMake(0, 0, 20.0, 19.0)];
    
    NSMenu *sortMenu = [[NSMenu alloc] init];
    NSMenuItem *m;
    
    NSString *dateAsc = NSLocalizedString(@"Oldest on Top", nil);
    NSString *dateDesc = NSLocalizedString(@"Newest on Top", nil);
    
    NSString *strAsc = NSLocalizedString(@"A to Z", nil);
    NSString *strDesc = NSLocalizedString(@"Z to A", nil);
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Date Created", nil) action:@selector(changeSort:) keyEquivalent:@""];
    m.representedObject =
    @{ @"key": @"createdAt",
       @"dir": @"desc",
       @"asc": dateAsc,
       @"desc": dateDesc };
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Date Modified", nil) action:@selector(changeSort:) keyEquivalent:@""];
    m.representedObject =
    @{ @"key": @"updatedAt",
       @"dir": @"desc",
       @"asc": dateAsc,
       @"desc": dateDesc };
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Date Closed", nil) action:@selector(changeSort:) keyEquivalent:@""];
    m.representedObject =
    @{ @"key": @"closedAt",
       @"dir": @"desc",
       @"asc": dateAsc,
       @"desc": dateDesc };
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Assignee", nil) action:@selector(changeSort:) keyEquivalent:@""];
    m.representedObject =
    @{ @"key": @"assignee.login",
       @"dir": @"asc",
       @"compare": @"localizedStandardCompare:",
       @"asc": strAsc,
       @"desc": strDesc };
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Author", nil) action:@selector(changeSort:) keyEquivalent:@""];
    m.representedObject =
    @{ @"key": @"originator.login",
       @"dir": @"asc",
       @"compare": @"localizedStandardCompare:",
       @"asc": strAsc,
       @"desc": strDesc };
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Title", nil) action:@selector(changeSort:) keyEquivalent:@""];
    m.representedObject =
    @{ @"key": @"title",
       @"dir": @"asc",
       @"compare": @"localizedStandardCompare:",
       @"asc": strAsc,
       @"desc": strDesc };
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Labels", nil) action:@selector(changeSort:) keyEquivalent:@""];
    m.representedObject =
    @{ @"key": @"labels",
       @"dir": @"desc",
       @"target": @"self",
       @"compare": @"labelsCompare:",
       @"asc": strAsc,
       @"desc": strDesc };
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Unread", nil) action:@selector(changeSort:) keyEquivalent:@""];
    m.representedObject =
    @{ @"key": @"unread",
       @"dir" : @"desc" };
    
    [sortMenu addItem:[NSMenuItem separatorItem]];
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Ascending", nil) action:@selector(changeSortDir:) keyEquivalent:@""];
    m.representedObject = @YES;
    
    m = [sortMenu addItemWithTitle:NSLocalizedString(@"Descending", nil) action:@selector(changeSortDir:) keyEquivalent:@""];
    m.representedObject = @NO;
    
    for (m in sortMenu.itemArray) {
        m.target = self;
    }
    
    
    header.sortButton.menu = sortMenu;
    
    [self.table setHeaderView:header];
    [self.table setCornerView:corner];
    
    [self.table setUsesAlternatingRowBackgroundColors:NO];
    [self.table setGridStyleMask:NSTableViewSolidHorizontalGridLineMask];
}

- (void)viewDidAppear {
    [super viewDidAppear];
    [self restoreSortFromDefaults];
}

- (void)restoreSortFromDefaults {
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"Issue3PaneTableSortKey"];
    NSNumber *savedDir = [[NSUserDefaults standardUserDefaults] objectForKey:@"Issue3PaneTableSortDir"];
    
    if ([savedKey isEqualToString:@"labels.@count"]) {
        savedKey = @"labels";
    }
    
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"updatedAt" ascending:NO];
    if (savedKey && savedDir) {
        sort = [NSSortDescriptor sortDescriptorWithKey:savedKey ascending:[savedDir boolValue]];
    }

    [self updateSort:sort];
}

- (void)updateSort:(NSSortDescriptor *)sortDesc {
    NSMenu *menu = _header.sortButton.menu;
    NSDictionary *info = nil;
    NSMenuItem *selectedItem = nil;
    for (NSMenuItem *item in menu.itemArray) {
        id r = item.representedObject;
        
        if ([r isKindOfClass:[NSDictionary class]]) {
            if ([r[@"key"] isEqualToString:sortDesc.key] || [r[@"target"] isEqualToString:sortDesc.key]) {
                info = r;
                item.state = NSOnState;
                selectedItem = item;
            } else {
                item.state = NSOffState;
            }
        } else {
            BOOL hide = info[@"asc"] == nil;
            item.hidden = hide;
            
            if (!hide && [r isKindOfClass:[NSNumber class]]) {
                BOOL asc = [r boolValue];
                
                item.state = asc == sortDesc.ascending;
                item.title = info[asc?@"asc":@"desc"];
            }
        }
    }
    
    if (selectedItem) {
        _header.sortButton.title = [NSString stringWithFormat:NSLocalizedString(@"Sort by %@", nil), selectedItem.title];
        [_header.sortButton sizeToFit];
        
        NSString *compare = info[@"compare"] ?: @"compare:";
        NSString *key = info[@"target"] ?: sortDesc.key;
        
        NSSortDescriptor *actual = [NSSortDescriptor sortDescriptorWithKey:[NSString stringWithFormat:@"%@", key] ascending:sortDesc.ascending selector:NSSelectorFromString(compare)];
        NSSortDescriptor *secondary = [NSSortDescriptor sortDescriptorWithKey:@"updatedAt" ascending:NO];
        [self.table setSortDescriptors:@[actual, secondary]];
    }
}

- (void)saveSortDefaults:(NSSortDescriptor *)sort {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if (!sort) {
        [d removeObjectForKey:@"Issue3PaneTableSortKey"];
        [d removeObjectForKey:@"Issue3PaneTableSortDir"];
    } else {
        [d setObject:sort.key forKey:@"Issue3PaneTableSortKey"];
        [d setBool:sort.ascending forKey:@"Issue3PaneTableSortDir"];
    }
}

- (IBAction)changeSort:(id)sender {
    NSMenuItem *item = sender;
    NSDictionary *info = item.representedObject;
    
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:info[@"key"] ascending:[info[@"dir"] isEqualToString:@"asc"]];
    [self updateSort:sort];
    
    [self saveSortDefaults:sort];
}

- (IBAction)changeSortDir:(id)sender {
    NSMenuItem *item = sender;
    BOOL asc = [item.representedObject boolValue];
    
    NSSortDescriptor *sort = [[self.table sortDescriptors] firstObject];
    if (sort) {
        sort = [NSSortDescriptor sortDescriptorWithKey:sort.key ascending:asc];
        [self updateSort:sort];
    }
    
    [self saveSortDefaults:sort];
}

- (void)commonInit {
    [super commonInit];
    self.defaultColumns = [NSSet setWithArray:@[@"number"]];
}

- (void)setUpNextMode:(BOOL)mode {
    if (mode != self.upNextMode) {
        [super setUpNextMode:mode];
        if (mode) {
            self.table.headerView = nil;
            self.table.cornerView = nil;
        } else {
            self.table.headerView = _header;
            self.table.cornerView = _corner;
            [self restoreSortFromDefaults];
        }
    }
}

- (BOOL)usesAlternatingRowBackgroundColors {
    return NO;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    return nil;
}

- (nullable NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row
{
    CompactIssueCellViewController *vc = nil;
    if ([_reuseQueue count] > 0) {
        vc = [_reuseQueue lastObject];
        [_reuseQueue removeLastObject];
    } else {
        vc = [CompactIssueCellViewController new];
    }
    vc.issue = self.items[row];
    return (NSTableRowView *)vc.view;
}

- (void)tableView:(NSTableView *)tableView didRemoveRowView:(NSTableRowView *)rowView forRow:(NSInteger)row {
    CompactIssueCellViewController *vc = [(id)rowView controller];
    if (vc) {
        [vc prepareForReuse];
        if ([_reuseQueue count] < 10) {
            if (!_reuseQueue) _reuseQueue = [NSMutableArray new];
        }
    }
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    return [CompactIssueCellViewController cellHeight];
}

- (NSString *)tableView:(NSTableView *)tableView typeSelectStringForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return nil;
}

- (BOOL)tableView:(NSTableView *)tableView handleKeyPressEvent:(NSEvent *)event {
    if ([event isSpace] && [event modifierFlagsAreExclusively:NSEventModifierFlagShift]) {
        [self.delegate issueTableController:self pageAuxiliaryViewBy:-1];
        return YES;
    } else if ([event isSpace]) {
        [self.delegate issueTableController:self pageAuxiliaryViewBy:1];
        return YES;
    } else if ([event isTabKey]) {
        if ([event modifierFlagsAreExclusively:NSShiftKeyMask]) {
            [self.delegate issueTableControllerFocusPreviousView:self];
        } else {
            [self.delegate issueTableControllerFocusNextView:self];
        }
        return YES;
    } else {
        return [super tableView:tableView handleKeyPressEvent:event];
    }
}

@end

@implementation CompactIssueTable

@dynamic delegate;

- (void)drawGridInClipRect:(NSRect)clipRect
{
    
}

@end

static NSColor *HeaderDividerColor() {
    static dispatch_once_t onceToken;
    static NSColor *color;
    dispatch_once(&onceToken, ^{
        color = [NSColor colorWithHexString:@"CECECE"];
    });
    return color;
}

@implementation CompactIssueTableHeaderView

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        FilterButton *button = [[FilterButton alloc] initWithFrame:CGRectMake(5.0, 1.0, 100.0, 16.0) pullsDown:YES];
        
        [button sizeToFit];
        _sortButton = button;
        
        [self addSubview:button];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    CGRect b = self.bounds;
    
    [[NSColor windowBackgroundColor] set];
    NSRectFill(self.bounds);
    
    [HeaderDividerColor() set];
    CGRect r = CGRectMake(0, CGRectGetHeight(b) - 1.0, b.size.width, 1.0);
    NSRectFill(r);
}

@end

@implementation CompactIssueTableCornerView

- (void)drawRect:(NSRect)dirtyRect {
    CGRect b = self.bounds;
    
    [[NSColor windowBackgroundColor] set];
    NSRectFill(self.bounds);
    
    [HeaderDividerColor() set];
    CGRect r = CGRectMake(0, 0, b.size.width, 1.0);
    NSRectFill(r);
}

@end

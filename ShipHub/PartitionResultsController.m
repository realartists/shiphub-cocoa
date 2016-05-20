//
//  PartitionResultsController.m
//  ShipHub
//
//  Created by James Howard on 5/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PartitionResultsController.h"

#import "AxisLockableScrollView.h"
#import "Extras.h"
#import "IssueTableController.h"
#import "Issue3PaneTableController.h"
#import "IssueTableControllerPrivate.h"
#import "DataStore.h"
#import "Issue.h"

@interface Partition : NSObject

@property NSString *label;
@property id representativeValue;
@property NSArray<Issue *> *issues;
@property id info;

@end

@interface PartitionScheme : NSObject

@property (nonatomic, readonly) NSString *defaultsValue;
@property (nonatomic, readonly) NSString *localizedDescription;
@property (nonatomic, readonly) NSString *keyPath;

// return nil if issue cannot be patched to destination, otherwise return a patch suitable to be used with -[DataStore patchIssue:...]
- (NSDictionary *)patch:(Issue *)issue toDestination:(Partition *)destination;

- (NSArray<Partition *> *)partition:(NSArray<Issue *> *)issues;

@end

@interface AssigneePartitionScheme : PartitionScheme
@end

@interface MilestonePartitionScheme : PartitionScheme
@end

@interface StatePartitionScheme : PartitionScheme
@end

@interface PartitionSelectorView : NSView

@property NSPopUpButton *partitionButton;

@end

@class PartitionHeaderView;

@interface PartitionTableController : Issue3PaneTableController

@property (nonatomic) NSString *label;
@property PartitionHeaderView *partitionHeader;

@end

@interface PartitionTableItem : NSObject <IssueTableItem>

@property (nonatomic, strong) Issue *issue;

@end

@implementation PartitionTableItem

- (id<NSCopying>)identifier {
    return [_issue fullIdentifier];
}

- (id)issueFullIdentifier {
    return [_issue fullIdentifier];
}

@end

@interface PartitionResultsController () <IssueTableControllerDelegate> {
    NSInteger _searchGeneration;
}

@property (nonatomic, assign) BOOL searching;
@property NSTimer *titleTimer;

@property NSArray<Issue *> *allIssues;
@property NSArray<Partition *> *partitionedIssues;

@property AxisLockableScrollView *hScroll;
@property NSView *canvas;
@property NSMutableArray<PartitionTableController *> *paneTables;

@property CGFloat columnMinWidth;
@property CGFloat columnSpacing;

@property PartitionSelectorView *selectorView;
@property NSArray *partitionSchemes;
@property PartitionScheme *activePartitionScheme;

@end

@implementation PartitionResultsController

- (id)init {
    if (self = [super init]) {
        _partitionSchemes = @[[AssigneePartitionScheme new], [MilestonePartitionScheme new], [StatePartitionScheme new]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    
    _selectorView = [[PartitionSelectorView alloc] initWithFrame:CGRectMake(0, 0, 600, 19.0)];
    [container addSubview:_selectorView];
    
    NSMenu *partitionMenu = [[NSMenu alloc] init];
    
    [partitionMenu addItemWithTitle:@" " action:nil keyEquivalent:@""]; // NSPopUpButton eats the first menu item.
    
    for (PartitionScheme *scheme in _partitionSchemes) {
        NSMenuItem *m = [partitionMenu addItemWithTitle:scheme.localizedDescription action:@selector(changePartitionScheme:) keyEquivalent:@""];
        m.representedObject = scheme;
        m.target = self;
    }
    
    _selectorView.partitionButton.menu = partitionMenu;
    
    _paneTables = [NSMutableArray new];
    
    _columnMinWidth = 240.0;
    _columnSpacing = 8.0;
    
    _hScroll = [[AxisLockableScrollView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    _hScroll.disableVerticalScrolling = YES;
    _hScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    _hScroll.hasVerticalScroller = NO;
    _hScroll.hasHorizontalScroller = YES;
    _hScroll.borderType = NSNoBorder;
    _hScroll.scrollerStyle = NSScrollerStyleOverlay;
    _hScroll.autohidesScrollers = YES;
    _hScroll.backgroundColor = [NSColor windowBackgroundColor];
    
    _canvas = [NSView new];
    _hScroll.documentView = _canvas;
    
    [container addSubview:_hScroll];
    
    self.view = container;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSourceUpdated:) name:DataStoreDidUpdateProblemsNotification object:nil];
    
    NSString *savedScheme = [[NSUserDefaults standardUserDefaults] stringForKey:@"PartitionResultsMode"];
    PartitionScheme *initialScheme = [_partitionSchemes firstObject];
    if (savedScheme) {
        for (PartitionScheme *scheme in _partitionSchemes) {
            if ([scheme.defaultsValue isEqualToString:savedScheme]) {
                initialScheme = scheme;
                break;
            }
        }
    }
    
    [self updatePartitionScheme:initialScheme];
}

- (void)changePartitionScheme:(id)sender {
    PartitionScheme *scheme = [sender representedObject];
    if (scheme) {
        [self updatePartitionScheme:scheme];
    }
}

- (void)updatePartitionScheme:(PartitionScheme *)scheme {
    NSMenu *menu = _selectorView.partitionButton.menu;
    for (NSMenuItem *item in menu.itemArray) {
        PartitionScheme *s = item.representedObject;
        if (s == scheme) {
            item.state = NSOnState;
        } else {
            item.state = NSOffState;
        }
    }
    
    _selectorView.partitionButton.title = [NSString stringWithFormat:NSLocalizedString(@"Partition by %@", nil), scheme.localizedDescription];
    [_selectorView.partitionButton sizeToFit];
    
    CGRect f = _selectorView.partitionButton.frame;
    f.size.width -= 12.0; // for some reason NSPopUpButton wants to put the chevron too far right. Stop that shit.
    _selectorView.partitionButton.frame = f;
    
    _activePartitionScheme = scheme;
    
    [self updateIssues:_allIssues];
}

- (void)dataSourceUpdated:(NSNotification *)note {
    [self refresh:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    return [[DataStore activeStore] isValid];
}


- (NSSize)preferredMinimumSize {
    return NSMakeSize(_columnMinWidth*2.0 + _columnSpacing*3.0, 400.0);
}

- (IBAction)refresh:(id)sender {
    _searchGeneration++;
    
    if (!self.predicate) {
        self.searching = NO;
        _allIssues = nil;
        _partitionedIssues = nil;
        [self didUpdateItems];
        return;
    }
    
    NSInteger generation = _searchGeneration;
    self.searching = YES;
    
    [[DataStore activeStore] issuesMatchingPredicate:self.predicate completion:^(NSArray<Issue *> *issues, NSError *error) {
        if (generation != _searchGeneration) return;
        
        if (issues) {
            [self updateIssues:issues];
        } else {
            [self presentError:error modalForWindow:self.view.window delegate:nil didPresentSelector:nil contextInfo:NULL];
        }
        self.searching = NO;
    }];
}

- (void)viewWillLayout {
    [super viewWillLayout];
    
    CGRect b = self.view.bounds;
    _selectorView.frame = CGRectMake(0, CGRectGetHeight(b) - 19.0, CGRectGetWidth(b), 19.0);
    _hScroll.frame = CGRectMake(0, 0, CGRectGetWidth(b), CGRectGetHeight(b) - 19.0);
    
    [self layoutTables];
}

- (void)updateIssues:(NSArray *)issues {
    NSAssert(_activePartitionScheme != nil, nil);
    
    _allIssues = issues;
    _partitionedIssues = [_activePartitionScheme partition:issues];
    [self didUpdateItems];
}

- (void)didUpdateItems {
    NSInteger currentCols = _canvas.subviews.count;
    NSInteger neededCols = _partitionedIssues.count;
    
    while (currentCols < neededCols) {
        PartitionTableController *c = [PartitionTableController new];
        [_paneTables addObject:c];
        c.delegate = self;
        [_canvas addSubview:c.view];
        currentCols++;
    }
    while (currentCols > neededCols) {
        Issue3PaneTableController *c = [_paneTables lastObject];
        c.delegate = nil;
        [_paneTables removeLastObject];
        [c.view removeFromSuperview];
        currentCols--;
    }
    
    for (NSInteger i = 0; i < neededCols; i++) {
        PartitionTableController *pane = _paneTables[i];
        Partition *part = _partitionedIssues[i];
        pane.tableItems = [part.issues arrayByMappingObjects:^id(Issue *obj) {
            PartitionTableItem *ti = [PartitionTableItem new];
            ti.issue = obj;
            return ti;
        }];
        pane.label = part.label;
    }
    
    [self layoutTables];
}

- (void)setPredicate:(NSPredicate *)predicate {
    [super setPredicate:predicate];
    [self refresh:nil];
}

- (void)titleTimerFired:(NSTimer *)timer {
    self.titleTimer = nil;
    self.title = nil;
}

- (void)setSearching:(BOOL)searching {
    _searching = searching;
    self.inProgress = searching;
    
    if (searching) {
        if (!self.titleTimer) {
            self.titleTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(titleTimerFired:) userInfo:nil repeats:NO];
        }
    } else {
        [self.titleTimer invalidate];
        self.titleTimer = nil;
        NSUInteger count = _allIssues.count;
        if (count != 1) {
            self.title = [NSString localizedStringWithFormat:NSLocalizedString(@"%td items", nil), count];
        } else {
            self.title = NSLocalizedString(@"1 item", nil);
        }
    }
}

- (void)layoutTables {
    NSInteger count = self.paneTables.count;
    CGRect bounds = _hScroll.bounds;
    CGFloat spacing = self.columnSpacing;
    CGFloat width = (CGRectGetWidth(bounds) - (spacing * (CGFloat)(count+1))) / (CGFloat)count;
    width = floor(MAX(width, _columnMinWidth));
    CGFloat totalWidth = width * count + (spacing * (count + 1));
    CGFloat yGap = totalWidth <= CGRectGetWidth(bounds) ? 0.0 : _hScroll.horizontalScroller.frame.size.height;
    CGFloat height = CGRectGetHeight(bounds) - yGap;
    CGFloat xOff = spacing;
    
    for (PartitionTableController *controller in self.paneTables) {
        NSView *view = controller.view;
        
        CGRect frame = CGRectMake(xOff, 0.0, width, height);
        xOff += width + spacing;
        
        view.frame = frame;
    }
    
    [_canvas setFrameSize:CGSizeMake(xOff, height)];
}

- (void)issueTableController:(IssueTableController *)controller didChangeSelection:(NSArray<Issue *> *)selectedIssues {
    if (selectedIssues.count > 0) {
        for (PartitionTableController *c in self.paneTables) {
            if (c != controller) {
                [c selectItems:nil];
            }
        }
    }
}

@end

@interface PartitionScrollView : NSScrollView

@end

@interface PartitionHeaderView : NSTableHeaderView

@property (nonatomic) NSString *label;

@end

@implementation PartitionTableController

+ (Class)scrollViewClass {
    return [PartitionScrollView class];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _partitionHeader = [[PartitionHeaderView alloc] initWithFrame:CGRectMake(0, 0, self.table.bounds.size.width, 28.0)];
    self.table.headerView = _partitionHeader;
    
    BackgroundColorView *corner = [[BackgroundColorView alloc] initWithFrame:CGRectMake(0, 0, 28.0, 28.0)];
    corner.backgroundColor = [NSColor windowBackgroundColor];
    self.table.cornerView = corner;
}

- (void)setLabel:(NSString *)label {
    _partitionHeader.label = label;
}

- (NSString *)label {
    return _partitionHeader.label;
}

@end

@implementation PartitionHeaderView

- (void)setLabel:(NSString *)label {
    _label = label;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    CGRect b = self.bounds;
    [[NSColor windowBackgroundColor] set];
    NSRectFill(b);
    
    NSDictionary *attrs = @{ NSForegroundColorAttributeName : [NSColor blackColor],
                             NSFontAttributeName : [NSFont boldSystemFontOfSize: 18.0] };
    
    NSString *label = _label ?: NSLocalizedString(@"Not Set", nil);
    CGSize s = [label sizeWithAttributes:attrs];
    
    CGRect r = CenteredRectInRect(b, CGRectMake(0, 0, s.width, s.height));
    [label drawInRect:r withAttributes:attrs];
}

@end

@implementation PartitionScrollView

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        [super setScrollerStyle:NSScrollerStyleOverlay];
    }
    return self;
}

- (void)setScrollerStyle:(NSScrollerStyle)scrollerStyle {
    scrollerStyle = NSScrollerStyleOverlay;
    [super setScrollerStyle:scrollerStyle];
}

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window) {
        [self flashScrollers];
    }
}

@end


@implementation PartitionSelectorView

- (id)initWithFrame:(NSRect)frame {
    if (self = [super initWithFrame:frame]) {
        NSPopUpButton *button = [[NSPopUpButton alloc] initWithFrame:CGRectMake(5.0, 1.0, 100.0, 16.0) pullsDown:YES];
        NSPopUpButtonCell *cell = button.cell;
        cell.arrowPosition = NSPopUpArrowAtBottom;
        button.autoenablesItems = YES;
        button.controlSize = NSSmallControlSize;
        button.state = NSOnState;
        button.preferredEdge = NSRectEdgeMinY;
        [button setButtonType:NSPushOnPushOffButton];
        button.font = [NSFont systemFontOfSize:10.0];
        button.bezelStyle = NSRecessedBezelStyle;
        button.showsBorderOnlyWhileMouseInside = YES;
        
        [button sizeToFit];
        _partitionButton = button;
        
        [self addSubview:button];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    CGRect b = self.bounds;
    
    [[NSColor windowBackgroundColor] set];
    NSRectFill(self.bounds);
    
    [[NSColor extras_tableHeaderDividerColor] set];
    CGRect r = CGRectMake(0, 0, b.size.width, 1.0);
    NSRectFill(r);
}

@end

@implementation Partition

@end

@implementation PartitionScheme

- (NSString *)defaultsValue {
    return NSStringFromClass([self class]);
}

- (NSString *)localizedDescription {
    return [self defaultsValue];
}

- (NSString *)keyPath {
    return @"fullIdentifier";
}

- (NSDictionary *)patch:(Issue *)issue toDestination:(Partition *)destination
{
    return nil;
}

- (NSArray<Partition *> *)partition:(NSArray<Issue *> *)issues {
    
    NSMutableArray *parts = [NSMutableArray new];
    for (NSArray *l in [issues partitionByKeyPath:self.keyPath]) {
        
        Partition *p = [Partition new];
        p.issues = l;
        p.representativeValue = [[l firstObject] valueForKeyPath:self.keyPath];
        p.label = [p.representativeValue description] ?: NSLocalizedString(@"Not Set", nil);
        
        [parts addObject:p];
    }
    
    [parts sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        
        id a = [obj1 representativeValue];
        id b = [obj2 representativeValue];
        
        if (!a && b) {
            return NSOrderedAscending;
        } else if (a && !b) {
            return NSOrderedDescending;
        } else if (!a && !b) {
            return NSOrderedSame;
        } else {
            if ([a respondsToSelector:@selector(localizedStandardCompare:)]) {
                return [a localizedStandardCompare:b];
            } else {
                return [a compare:b];
            }
        }
    }];
    
    return parts;
}

@end

@implementation AssigneePartitionScheme

- (NSString *)keyPath {
    return @"assignee.login";
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Assignee", nil);
}

@end

@implementation MilestonePartitionScheme

- (NSString *)keyPath {
    return @"milestone.title";
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"Milestone", nil);
}

@end

@implementation StatePartitionScheme

- (NSString *)keyPath {
    return @"state";
}

- (NSString *)localizedDescription {
    return NSLocalizedString(@"State", nil);
}

@end

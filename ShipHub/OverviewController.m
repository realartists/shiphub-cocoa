//
//  OverviewController.m
//  Ship
//
//  Created by James Howard on 6/3/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "OverviewController.h"

#import "AppDelegate.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Extras.h"
#import "Milestone.h"
#import "Repo.h"
#import "OverviewNode.h"
#import "SearchResultsController.h"
#import "User.h"
#import "Auth.h"
#import "SearchFieldToolbarItem.h"
#import "ButtonToolbarItem.h"
#import "NSPredicate+Extras.h"
#import "NSImage+Icons.h"
#import "ResultsViewModeItem.h"
#import "Sparkline.h"
#import "NetworkStateWindow.h"
#import "ChartController.h"
#import "TimeSeries.h"
#import "ThreePaneController.h"
#import "FilterBarViewController.h"
#import "IssueIdentifier.h"
#import "UpNextHelper.h"
#import "IssueDocumentController.h"
#import "SearchSheet.h"
#import "CustomQuery.h"
#import "BulkModifyHelper.h"
#import "NewMilestoneController.h"

//#import "OutboxViewController.h"
//#import "AttachmentProgressViewController.h"



//#import "ProblemProgressController.h"

#import <QuartzCore/QuartzCore.h>

static NSString *const LastSelectedNodeDefaultsKey = @"OverviewLastSelectedNode";
static NSString *const LastSelectedModeDefaultsKey = @"OverviewLastSelectedMode";

@interface OverviewWindow : NetworkStateWindow

@end

@interface OverviewOutlineView : NSOutlineView

- (id)selectedItem;

@end

@interface OverviewProgressIndicator : NSView

@property (nonatomic, assign) double doubleValue;
@property (nonatomic, assign) NSInteger openCount;
@property (nonatomic, assign) NSInteger closedCount;

@end

@interface OverviewCellView : NSTableCellView

@end

@interface OverviewCountCellView : NSTableCellView

@property IBOutlet NSButton *countButton;

@end

@interface OverviewOwnerCellView : OverviewCellView

@property IBOutlet NSButton *warningButton;
@property IBOutlet NSLayoutConstraint *warningWidth;

@end

@interface OverviewMilestoneCellView : OverviewCellView

@property IBOutlet OverviewProgressIndicator *progressIndicator;

@end

@interface OverviewController () <NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate, NSWindowDelegate, FilterBarViewControllerDelegate, NSTextFieldDelegate>

@property SearchResultsController *searchResults;
@property ThreePaneController *threePaneController;
@property ChartController *chartController;

@property (strong) IBOutlet NSSplitView *splitView;
@property (strong) IBOutlet OverviewOutlineView *outlineView;

@property (strong) IBOutlet SearchFieldToolbarItem *searchItem;
@property (strong) IBOutlet ButtonToolbarItem *predicateItem;
@property (strong) IBOutlet ButtonToolbarItem *createNewItem;
@property (strong) IBOutlet ButtonToolbarItem *sidebarItem;
@property (strong) IBOutlet ResultsViewModeItem *modeItem;

@property (strong) FilterBarViewController *filterBar;

@property (strong) IBOutlet NSPopUpButton *addButton;

@property NSArray *outlineRoots;

@property OverviewNode *allProblemsNode;
@property OverviewNode *upNextNode;
@property OverviewNode *attachmentsNode;
@property OverviewNode *outboxNode;

@property NSString *nextNodeToSelect;
@property BOOL nodeSelectionProgrammaticallyInitiated;

#if !INCOMPLETE
@property ProblemProgressController *initialSyncController;
#endif

@end

@implementation OverviewController

- (void)dealloc {
    if ([self isWindowLoaded]) {
        [[self window] removeObserver:self forKeyPath:@"firstResponder"];
        [_searchResults removeObserver:self forKeyPath:@"title"];
        [_chartController removeObserver:self forKeyPath:@"title"];
        [_threePaneController removeObserver:self forKeyPath:@"title"];
    }
    _outlineView.delegate = nil;
    _outlineView.dataSource = nil;
    _splitView.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)windowNibName {
    return @"OverviewController";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
//    self.window.titleVisibility = NSWindowTitleHidden;
    
    static BOOL isElCapOrNewer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
        isElCapOrNewer = (version.majorVersion == 10 && version.minorVersion >= 11) || (version.majorVersion > 10);
    });

    if (isElCapOrNewer) {
        _splitView.wantsLayer = YES;
    }
    
    _filterBar = [FilterBarViewController new];
    _filterBar.delegate = self;
    [_filterBar addToWindow:self.window];
    
    NSImage *sidebarImage = [NSImage sidebarIcon];
    _sidebarItem.buttonImage = sidebarImage;
    _sidebarItem.toolTip = NSLocalizedString(@"Toggle Sidebar", nil);
    _sidebarItem.trackingMode = NSSegmentSwitchTrackingSelectAny;
    
    _createNewItem.buttonImage = [NSImage imageNamed:@"NSToolbarCompose"];
    _createNewItem.toolTip = NSLocalizedString(@"New Problem ⌘N", nil);
    
    _predicateItem.buttonImage = [NSImage advancedSearchIcon];
    _predicateItem.toolTip = NSLocalizedString(@"New Smart Query ⌥⌘F", nil);
    
    _searchItem.searchField.placeholderString = NSLocalizedString(@"Filter", nil);
    [[self window] addObserver:self forKeyPath:@"firstResponder" options:0 context:NULL];
    
    _searchResults = [[SearchResultsController alloc] init];
    [_searchResults addObserver:self forKeyPath:@"title" options:0 context:NULL];
    
    _searchItem.searchField.nextKeyView = [_searchResults.view subviews][0];
    _searchItem.searchField.nextKeyView.nextKeyView = _searchItem.searchField;
    
    _threePaneController = [[ThreePaneController alloc] init];
    [_threePaneController addObserver:self forKeyPath:@"title" options:0 context:NULL];

    _chartController = [[ChartController alloc] init];
    [_chartController addObserver:self forKeyPath:@"title" options:0 context:NULL];
    
    ResultsViewMode initialMode = [[Defaults defaults] integerForKey:LastSelectedModeDefaultsKey fallback:ResultsViewMode3Pane];
    _modeItem.mode = initialMode;
    [self changeResultsMode:nil];
    
    [_splitView setPosition:240.0 ofDividerAtIndex:0];
    
    _outlineView.floatsGroupRows = NO;
    [_outlineView registerForDraggedTypes:@[(__bridge NSString *)kUTTypeURL, (__bridge NSString *)kUTTypeRTF, (__bridge NSString *)kUTTypePlainText]];
    
    self.window.frameAutosaveName = @"Overview";
    _splitView.autosaveName = @"OverviewSplit";
    
    CGFloat dividerPos = [[[_splitView subviews] objectAtIndex:0] frame].size.width;
    if (dividerPos > 0.0 && dividerPos < 180.0) {
        [_splitView setPosition:240.0 ofDividerAtIndex:0];
        [self updateSidebarItem];
    }

    [self buildOutline];
    if ([[_outlineView selectedItem] filterBarDefaultsToOpenState]) {
        [_filterBar resetFilters:[NSPredicate predicateWithFormat:@"closed = NO"]];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataChanged:) name:DataStoreDidUpdateMetadataNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataStoreChanged:) name:DataStoreActiveDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queriesChanged:) name:DataStoreDidUpdateMyQueriesNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(problemsChanged:) name:DataStoreDidUpdateProblemsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialSyncStarted:) name:DataStoreWillBeginInitialMetadataSync object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialSyncEnded:) name:DataStoreDidEndInitialMetadataSync object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outboxChanged:) name:DataStoreDidUpdateOutboxNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(upNextChanged:) name:DataStoreDidUpdateMyUpNextNotification object:nil];
}

- (IBAction)showWindow:(id)sender {
    [super showWindow:sender];
    
    if ([[DataStore activeStore] isPerformingInitialSync]) {
        [self initialSyncStarted:nil];
    }
}

- (void)initialSyncStarted:(NSNotification *)note {
#if !INCOMPLETE
    if (!_initialSyncController) {
        _initialSyncController = [ProblemProgressController new];
        _initialSyncController.message = NSLocalizedString(@"Syncing initial metadata ...", nil);
    }
    
    if (!_initialSyncController.window.sheetParent) {
        [_initialSyncController beginSheetInWindow:self.window];
    }
#endif
}

- (void)initialSyncEnded:(NSNotification *)note {
#if !INCOMPLETE
    [_initialSyncController endSheet];
#endif
}

- (NSMenu *)menuForCustomQuery:(CustomQuery *)query {
    NSMenu *menu = [NSMenu new];
    menu.extras_representedObject = query;
    if ([query.authorIdentifier isEqual:[[User me] identifier]]) {
        [menu addItemWithTitle:NSLocalizedString(@"Edit Query", nil) action:@selector(editQuery:) keyEquivalent:@""];
        [menu addItemWithTitle:NSLocalizedString(@"Rename Query", nil) action:@selector(renameQuery:) keyEquivalent:@""];
    }
    [menu addItemWithTitle:NSLocalizedString(@"Remove Query", nil) action:@selector(removeQuery:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy Link", nil) action:@selector(copyQueryLink:) keyEquivalent:@""];
    return menu;
}

- (void)buildOutline {
    NSString *savedIdentifier = nil;
    if (_nextNodeToSelect) {
        savedIdentifier = _nextNodeToSelect;
    } else if ([[_outlineView selectedItem] identifier]) {
        savedIdentifier = [[_outlineView selectedItem] identifier];
    } else {
        NSString *lastViewedIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:LastSelectedNodeDefaultsKey];
        savedIdentifier = lastViewedIdentifier ?: @"AllProblems";
    }
    _nextNodeToSelect = nil;
    
    CGRect lastVisibleRect = [[_outlineView enclosingScrollView] documentVisibleRect];
    CGRect lastSelectedRect = CGRectZero;
    NSInteger lastSelectedRow = _outlineView.selectedRow;
    
    if (lastSelectedRow != -1) {
        lastSelectedRect = [_outlineView frameOfOutlineCellAtRow:_outlineView.selectedRow];
    }
    
    NSMutableDictionary *oldCounts = nil;
    if (_outlineRoots) {
        oldCounts = [NSMutableDictionary dictionary];
        [self walkNodes:^(OverviewNode *node) {
            if (node.showCount) {
                if (node.count != NSNotFound) {
                    oldCounts[node.identifier] = @(node.count);
                }
            } else if (node.showProgress) {
                if (node.progress >= 0.0) {
                    oldCounts[node.identifier] = @(node.progress);
                }
            }
        }];
    }
    
    NSMutableArray *roots = [NSMutableArray array];
    
    OverviewNode *topNode = [OverviewNode new];
    topNode.title = NSLocalizedString(@"Overview", nil);
    [roots addObject:topNode];
    
    _allProblemsNode = [OverviewNode new];
    _allProblemsNode.showCount = YES;
    _allProblemsNode.countOpenOnly = YES;
    _allProblemsNode.cellIdentifier = @"CountCell";
    _allProblemsNode.identifier = @"AllProblems";
    _allProblemsNode.title = NSLocalizedString(@"All Issues", nil);
    _allProblemsNode.predicate = [NSPredicate predicateWithValue:YES];
    _allProblemsNode.icon = [NSImage overviewIconNamed:@"928-inbox-files-selected"];
    [topNode addChild:_allProblemsNode];
    
    _upNextNode = [OverviewNode new];
    _upNextNode.showCount = YES;
    _upNextNode.cellIdentifier = @"CountCell";
    _upNextNode.allowChart = NO;
    _upNextNode.title = NSLocalizedString(@"Up Next", nil);
    _upNextNode.predicate = [NSPredicate predicateWithFormat:@"closed = NO AND ANY upNext.user.identifier = %@", [[User me] identifier]];
    _upNextNode.icon = [NSImage overviewIconNamed:@"1175-numbered-list"];
    __weak __typeof(self) weakSelf = self;
    _upNextNode.dropHandler = ^(NSArray *identifiers) {
        [[UpNextHelper sharedHelper] addToUpNext:identifiers atHead:NO window:weakSelf.window completion:nil];
    };
    [topNode addChild:_upNextNode];
    
    OverviewNode *notificationsNode = [OverviewNode new];
    notificationsNode.showCount = YES;
    notificationsNode.cellIdentifier = @"CountCell";
    notificationsNode.allowChart = NO;
    notificationsNode.filterBarDefaultsToOpenState = NO;
    notificationsNode.icon = [NSImage overviewIconNamed:@"756-bell-selected"];
    notificationsNode.title = NSLocalizedString(@"Notifications", nil);
    notificationsNode.predicate = [NSPredicate predicateWithFormat:@"notification.unread = YES"];
    NSMenu *notificationsMenu = [NSMenu new];
    [notificationsMenu addItemWithTitle:@"Mark All Notifications as Read" action:@selector(markAllNotificationsAsRead:) keyEquivalent:@""];
    notificationsNode.menu = notificationsMenu;
    [topNode addChild:notificationsNode];
    
    OverviewNode *milestonesRoot = [OverviewNode new];
//    milestonesRoot.representedObject = _milestoneMap;
    milestonesRoot.title = NSLocalizedString(@"Milestones", nil);
    [roots addObject:milestonesRoot];
    
    MetadataStore *metadata = [[DataStore activeStore] metadataStore];
    
    NSImage *milestoneIcon = [NSImage overviewIconNamed:@"563-calendar"];
    for (NSString *milestone in [metadata mergedMilestoneNames]) {
        OverviewNode *node = [OverviewNode new];
        node.cellIdentifier = @"MilestoneCell";
        node.representedObject = milestone;
        node.title = milestone;
        node.showProgress = YES;
        node.predicate = [NSPredicate predicateWithFormat:@"milestone.title = %@", milestone];
        node.icon = milestoneIcon;
        node.dropHandler = ^(NSArray *identifiers) {
            [[BulkModifyHelper sharedHelper] moveIssues:identifiers toMilestone:milestone window:weakSelf.window completion:nil];
        };
        [milestonesRoot addChild:node];
    }
    
    OverviewNode *backlog = [OverviewNode new];
    backlog.title = NSLocalizedString(@"Backlog", nil);
    backlog.predicate = [NSPredicate predicateWithFormat:@"milestone = nil AND closed = NO"];
    backlog.showCount = YES;
    backlog.cellIdentifier = @"CountCell";
    backlog.icon = [NSImage overviewIconNamed:@"832-stack-1"];
    [milestonesRoot addChild:backlog];
    
    NSArray *queries = [[DataStore activeStore] myQueries];
    if ([queries count] > 0) {
        NSImage *queryIcon = [NSImage overviewIconNamed:@"666-gear2"];
        NSArray *myQueries = [queries sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        OverviewNode *myQueriesRoot = [OverviewNode new];
        myQueriesRoot.title = NSLocalizedString(@"Smart Queries", nil);
        [roots addObject:myQueriesRoot];
        
        for (CustomQuery *query in myQueries) {
            OverviewNode *queryNode = [OverviewNode new];
            queryNode.title = query.titleWithAuthor;
            queryNode.representedObject = query;
            queryNode.predicate = query.predicate;
            queryNode.identifier = query.identifier;
            queryNode.menu = [self menuForCustomQuery:query];
            queryNode.titleEditable = YES;
            queryNode.showCount = YES;
            queryNode.cellIdentifier = @"CountCell";
            queryNode.icon = queryIcon;
            [myQueriesRoot addChild:queryNode];
        }
    }
    
    OverviewNode *reposNode = [OverviewNode new];
    reposNode.title = NSLocalizedString(@"Repos", nil);
    [roots addObject:reposNode];
    
    BOOL multipleOwners = [[metadata repoOwners] count] > 1;
    
    for (Account *repoOwner in [metadata repoOwners]) {
        
        OverviewNode *parent = reposNode;
        OverviewNode *ownerNode = nil;
        if (multipleOwners) {
            ownerNode = [OverviewNode new];
            ownerNode.cellIdentifier = @"OwnerCell";
            ownerNode.title = repoOwner.login;
            ownerNode.representedObject = repoOwner;
            ownerNode.predicate = [NSPredicate predicateWithFormat:@"repository.owner.login = %@", repoOwner.login];
            ownerNode.icon = [repoOwner isKindOfClass:[Org class]] ? [NSImage overviewIconNamed:@"974-users-selected"] : [NSImage overviewIconNamed:@"973-user-selected"];
            [reposNode addChild:ownerNode];
            
            parent = ownerNode;
        }
        
        for (Repo *repo in [metadata reposForOwner:repoOwner]) {
            OverviewNode *repoNode = [OverviewNode new];
            repoNode.cellIdentifier = @"CountCell";
            repoNode.representedObject = repo;
            repoNode.title = repo.name;
            repoNode.icon = [NSImage overviewIconNamed:@"710-folder"];
            repoNode.showCount = YES;
            repoNode.countOpenOnly = YES;
            repoNode.predicate = [NSPredicate predicateWithFormat:@"repository.identifier = %@", repo.identifier];
            [parent addChild:repoNode];
            
            if (repo.shipNeedsWebhookHelp) {
                ownerNode.showWarning = YES;
            }
        }
        
        if (ownerNode.showWarning) {
            NSString *warningHiddenKey = [NSString stringWithFormat:@"WebhookWarningHidden.%@", repoOwner.identifier];
            BOOL warningHidden = [[NSUserDefaults standardUserDefaults] boolForKey:warningHiddenKey];
            if (warningHidden) {
                ownerNode.showWarning = NO;
            }
        }
    }
    
#if 0
    OverviewNode *statusRoot = [OverviewNode new];
    statusRoot.title = NSLocalizedString(@"System Status", nil);
    [roots addObject:statusRoot];
    
    OverviewNode *outbox = _outboxNode = [OverviewNode new];
    outbox.title = NSLocalizedString(@"Outbox", nil);
    outbox.showCount = YES;
#if !INCOMPLETE
    outbox.viewController = [OutboxViewController new];
#endif
    outbox.icon = [NSImage overviewIconNamed:@"560-shipping-box"];
    [statusRoot addChild:outbox];
    
    OverviewNode *attachments = _attachmentsNode = [OverviewNode new];
    attachments.title = NSLocalizedString(@"File Progress", nil);
#if !INCOMPLETE
    attachments.viewController = [AttachmentProgressViewController new];
#endif
    attachments.icon = [NSImage overviewIconNamed:@"924-inbox-download-selected"];
    [statusRoot addChild:attachments];
    
#if !INCOMPLETE
    OverviewNode *inactiveRoot = [OverviewNode new];
    inactiveRoot.representedObject = _milestoneMap;
    inactiveRoot.identifier = @"InactiveMilestones";
    inactiveRoot.title = NSLocalizedString(@"Inactive Milestones", nil);
    [roots addObject:inactiveRoot];
    
    for (Milestone *milestone in [_milestoneMap inactiveMilestones]) {
        OverviewNode *node = [OverviewNode new];
        node.representedObject = milestone;
        node.title = milestone.name;
        node.predicate = [NSPredicate predicateWithFormat:@"milestone.identifier = %@", milestone.identifier];
        node.toolTip = [milestone localizedDateRange];
        node.icon = milestoneIcon;
        [inactiveRoot addChild:node];
    }
#endif
    
#endif
    
    _outlineRoots = roots;
    
    if (oldCounts) {
        [self walkNodes:^(OverviewNode *node) {
            NSNumber *count = oldCounts[node.identifier];
            if (count && node.showCount) {
                node.count = count.unsignedIntegerValue;
            } else if (count && node.showProgress) {
                node.progress = count.doubleValue;
            }
        }];
    }
    
    [_outlineView reloadData];
    [self expandDefault];
    
    if (savedIdentifier) {
        [self selectItemsMatchingPredicate:[NSPredicate predicateWithFormat:@"identifier = %@", savedIdentifier]];
    }
    
    if (savedIdentifier && lastSelectedRow != -1) {
        CGRect newRect = [_outlineView frameOfOutlineCellAtRow:_outlineView.selectedRow];
        CGRect documentRect = lastVisibleRect;
        documentRect.origin.y -= newRect.origin.y - lastSelectedRect.origin.y;
        documentRect = CGRectIntersection(_outlineView.frame, documentRect);
        [_outlineView scrollRectToVisible:documentRect];
    }
    
    [self updateCounts:nil];
}

- (void)updateCount:(OverviewNode *)node {
    if (node.predicate && node.showProgress) {
        void (^updateProgress)(double, NSInteger, NSInteger) = ^(double progress, NSInteger open, NSInteger closed) {
            if (node.progress != progress) {
                node.progress = progress;
                NSInteger row = [_outlineView rowForItem:node];
                if (row >= 0) {
                    OverviewMilestoneCellView *view = [[_outlineView rowViewAtRow:row makeIfNecessary:NO] viewAtColumn:0];
                    if (view) {
                        OverviewProgressIndicator *progressIndicator = view.progressIndicator;
                        if (progress < 0.0) {
                            progressIndicator.hidden = YES;
                        } else {
                            progressIndicator.hidden = NO;
                            progressIndicator.doubleValue = progress;
                            progressIndicator.openCount = open;
                            progressIndicator.closedCount = closed;
                        }
                    }
                }
            }
        };
        
        [[DataStore activeStore] issueProgressMatchingPredicate:node.predicate completion:^(double progress, NSInteger open, NSInteger closed, NSError *error) {
            updateProgress(progress, open, closed);
        }];
        
    } else {
    
        void (^updateCount)(NSUInteger) = ^(NSUInteger count) {
            if (node.count != count) {
                node.count = count;
                NSInteger row = [_outlineView rowForItem:node];
                if (row >= 0) {
                    OverviewCountCellView *view = [[_outlineView rowViewAtRow:row makeIfNecessary:NO] viewAtColumn:0];
                    if (view) {
                        NSButton *countButton = view.countButton;
                        if (count != NSNotFound) {
                            countButton.title = [NSString localizedStringWithFormat:@"%tu", count];
                            countButton.hidden = NO;
                        } else {
                            countButton.title = @"";
                            countButton.hidden = YES;
                        }
                    }
                }
            }
        };
        
        if (node.predicate && node.showCount) {
            NSPredicate *predicate = node.predicate;
            if (node.countOpenOnly) {
                predicate = [predicate and:[NSPredicate predicateWithFormat:@"closed = NO"]];
            }
            
            [[DataStore activeStore] countIssuesMatchingPredicate:predicate completion:^(NSUInteger count, NSError *error) {
                updateCount(count);
            }];
        } else if (node == _outboxNode) {
    #if !INCOMPLETE
            [[DataStore activeStore] outboxWithCompletion:^(NSArray *outbox) {
                NSUInteger count = outbox.count;
                updateCount(count > 0 ? count : NSNotFound);
            }];
    #endif
        } else {
            node.count = NSNotFound;
        }
    }
}

- (void)updateCounts:(OverviewNode *)root {
    NSArray *elements = root ? root.children : _outlineRoots;
    [self walkNodes:elements expandedOnly:NO visitor:^(OverviewNode *node) {
        [self updateCount:node];
    }];
}

- (void)metadataChanged:(NSNotification *)note {
    Trace();
    [self buildOutline];
}

- (void)dataStoreChanged:(NSNotification *)note {
    [self buildOutline];
}

- (void)queriesChanged:(NSNotification *)note {
    [self buildOutline];
}

- (void)problemsChanged:(NSNotification *)note {
    [self updateCounts:nil];
}

- (void)outboxChanged:(NSNotification *)note {
    [self updateCount:_outboxNode];
}

- (void)upNextChanged:(NSNotification *)note {
    [self updateCount:_upNextNode];
    if (_upNextNode == [_outlineView selectedItem]) {
        [[self activeResultsController] refresh:nil];
    }
}

- (void)expandDefault {
    [self walkNodes:^(OverviewNode *node) {
        if (node.children.count > 0) {
            BOOL collapse = [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@.collapsed", node.identifier]];
            if (!collapse) {
                [_outlineView expandItem:node];
            }
        }
    }];
}

- (void)expandAndSelectItem:(OverviewNode *)node {
    NSMutableArray *path = [NSMutableArray new];
    OverviewNode *cursor = node;
    while (cursor.parent) {
        [path addObject:cursor.parent];
        cursor = cursor.parent;
    }
    for (OverviewNode *ancestor in [path reverseObjectEnumerator]) {
        [_outlineView expandItem:ancestor];
    }
    NSInteger idx = [_outlineView rowForItem:node];

    [_outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
}

- (void)selectItemsMatchingPredicate:(NSPredicate *)predicate {
    NSMutableIndexSet *indexes = [NSMutableIndexSet new];
    [self walkNodes:^(OverviewNode *node) {
        if ([indexes count] == 0 && [predicate evaluateWithObject:node]) {
            NSMutableArray *path = [NSMutableArray new];
            OverviewNode *cursor = node;
            while (cursor.parent) {
                [path addObject:cursor.parent];
                cursor = cursor.parent;
            }
            for (OverviewNode *ancestor in [path reverseObjectEnumerator]) {
                [_outlineView expandItem:ancestor];
            }
            NSInteger idx = [_outlineView rowForItem:node];
            [indexes addIndex:idx];
        }
    }];
    _nodeSelectionProgrammaticallyInitiated = YES;
    [_outlineView selectRowIndexes:indexes byExtendingSelection:NO];
    _nodeSelectionProgrammaticallyInitiated = NO;
}

#pragma mark -

- (ResultsController *)activeResultsController {
    switch (_modeItem.mode) {
        case ResultsViewModeList: return _searchResults;
        case ResultsViewMode3Pane: return _threePaneController;
        case ResultsViewModeChart: return _chartController;
    }
}

#pragma mark -

- (void)updatePredicate {
    NSPredicate *predicate = nil;
    id selectedItem = [_outlineView selectedItem];
    
    predicate = [selectedItem predicate];
    
    NSPredicate *filterPredicate = _filterBar.predicate;
    
    NSString *title = [[_searchItem.searchField stringValue] trim];
    NSInteger number = [title isDigits] ? [title integerValue] : 0;
    NSPredicate *searchPredicate = [title length] > 0 ? [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@", title] : nil;
    if (number != 0) {
        searchPredicate = [searchPredicate or:[NSPredicate predicateWithFormat:@"number = %ld", (long)number]];
    }
    if (predicate && searchPredicate) {
        predicate = [predicate and:searchPredicate];
    } else if (searchPredicate) {
        predicate = searchPredicate;
    }
    
    if (filterPredicate) {
        predicate = [predicate and:filterPredicate];
    }
    
    _modeItem.chartEnabled = (selectedItem == nil || [selectedItem allowChart]);
    
    [[self activeResultsController] setUpNextMode:selectedItem == _upNextNode];
    [[self activeResultsController] setPredicate:predicate];
    [self updateCount:selectedItem];
}

- (IBAction)refresh:(id)sender {
    [[self activeResultsController] refresh:sender];
}

- (void)nodeUpdatedPredicate:(OverviewNode *)node {
    [self updatePredicate];
}

- (void)updateTitle {
    OverviewNode *selectedItem = [_outlineView selectedItem];
    NSString *resultsTitle = [[self activeResultsController] title];
    
    if (!selectedItem) {
        self.window.title = NSLocalizedString(@"Overview", nil);
    } else {
        if (!selectedItem.viewController && [resultsTitle length] > 0) {
            self.window.title = [NSString localizedStringWithFormat:NSLocalizedString(@"Overview : %@ : %@", nil), selectedItem.path, resultsTitle];
        } else {
            self.window.title = [NSString stringWithFormat:NSLocalizedString(@"Overview : %@", nil), selectedItem.path];
        }
    }
}

#pragma mark -

- (IBAction)showPredicateEditor:(id)sender {
    SearchSheet *sheet = [SearchSheet new];
    [sheet beginSheetModalForWindow:self.window completionHandler:^(CustomQuery *query) {
        if (query) {
            self.nextNodeToSelect = query.identifier;
            [self selectItemsMatchingPredicate:[NSPredicate predicateWithFormat:@"identifier = %@", query.identifier]];
        }
    }];
}

#pragma mark -

- (IBAction)changeResultsMode:(id)sender {
    [[Defaults defaults] setInteger:_modeItem.mode forKey:LastSelectedModeDefaultsKey];
    [[_splitView subviews][1] setContentView:[[self activeResultsController] view]];
    [self updatePredicate];
    [self updateTitle];
    [self adjustWindowToMinimumSize];
}

#pragma mark -


- (void)walkNodes:(NSArray *)nodes expandedOnly:(BOOL)expandedOnly visitor:(void (^)(OverviewNode *node))visitor {
    for (OverviewNode *node in nodes) {
        visitor(node);
        if (!expandedOnly || [_outlineView isItemExpanded:node]) {
            [self walkNodes:node.children expandedOnly:expandedOnly visitor:visitor];
        }
    }
}

- (void)walkNodes:(void (^)(OverviewNode *node))visitor {
    [self walkNodes:_outlineRoots expandedOnly:NO visitor:visitor];
}

#pragma mark - NSOutlineViewDataSource & NSOutlineViewDelegate

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return [_outlineRoots count];
    } else if ([item isKindOfClass:[OverviewNode class]]) {
        OverviewNode *node = item;
        return node.children.count + node.knobs.count;
    } else {
        return 0;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if (item == nil) {
        return _outlineRoots[index];
    } else if ([item isKindOfClass:[OverviewNode class]]) {
        OverviewNode *node = item;
        if (index < node.knobs.count) {
            return [node.knobs objectAtIndex:index];
        } else {
            return [node.children objectAtIndex:index-node.knobs.count];
        }
    } else {
        return nil;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    if ([item isKindOfClass:[OverviewNode class]]) {
        OverviewNode *node = item;
        return node.children.count > 0;
    } else {
        return NO;
    }

}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item {
    id selectedItem = nil;
    if (outlineView.selectedRow >= 0) {
        selectedItem = [outlineView itemAtRow:outlineView.selectedRow];
    }
    if ([item isKindOfClass:[OverviewNode class]]) {
        OverviewNode *node = item;
        if (item == selectedItem && node.knobs.count > 0) return NO;
    }
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(OverviewNode *)item {
    if ([item isKindOfClass:[OverviewNode class]]) {
        OverviewNode *node = item;
        return (node.children.count + node.knobs.count) > 0;
    } else {
        return NO;
    }
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([item isKindOfClass:[OverviewNode class]]) {
        OverviewNode *node = item;
        OverviewCellView *cell = [outlineView makeViewWithIdentifier:node.cellIdentifier owner:self];
        
        if ([cell isKindOfClass:[OverviewCountCellView class]]) {
            OverviewCountCellView *countCell = (id)cell;
            NSButton *countButton = countCell.countButton;
            if (node.count != NSNotFound) {
                countButton.title = [NSString localizedStringWithFormat:@"%tu", node.count];
                countButton.hidden = NO;
            } else {
                countButton.title = @"";
                countButton.hidden = YES;
            }
        }
        
        if ([cell isKindOfClass:[OverviewMilestoneCellView class]]) {
            OverviewMilestoneCellView *mileCell = (id)cell;
            OverviewProgressIndicator *progress = mileCell.progressIndicator;
            
            if (node.showProgress) {
                progress.hidden = node.progress < 0.0;
                progress.doubleValue = MIN(MAX(node.progress, 0.0), 1.0);
            }
        }
        
        if ([cell isKindOfClass:[OverviewOwnerCellView class]]) {
            OverviewOwnerCellView *ownerCell = (id)cell;
            ownerCell.warningWidth.constant = node.showWarning?18.0:0.0;
            ownerCell.warningButton.extras_representedObject = node;
            ownerCell.warningButton.target = self;
            ownerCell.warningButton.action = @selector(showWebhookWarning:);
        }
        
        cell.imageView.image = node.icon;
        cell.textField.stringValue = node.title;
        cell.menu = node.menu;
        cell.textField.editable = node.titleEditable;
        cell.textField.target = self;
        cell.textField.action = @selector(commitRename:);
        cell.textField.delegate = self;
        cell.textField.extras_representedObject = node;
        cell.toolTip = node.toolTip;
        return cell;
    } else {
        NSAssert([item isKindOfClass:[OverviewKnob class]], @"Must be a knob if not a node");
        OverviewKnob *knob = item;
        return knob.view;
    }
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item {
    if ([item isKindOfClass:[OverviewNode class]]) return 20.0;
    else {
        NSAssert([item isKindOfClass:[OverviewKnob class]], @"Must be a knob if not a node");
        OverviewKnob *knob = item;
        return knob.view.frame.size.height;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    if ([item isKindOfClass:[OverviewNode class]]) {
        return [item title];
    } else {
        return [item view];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return [item isKindOfClass:[OverviewNode class]] && ([item predicate] != nil || [item viewController] != nil);
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
    return [_outlineRoots containsObject:item] && [item predicate] == nil && [item viewController] == nil;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
    OverviewNode *selectedItem = [_outlineView selectedItem];
    if (!_nodeSelectionProgrammaticallyInitiated) {
        [_searchItem.searchField setStringValue:@""];
        if (selectedItem.filterBarDefaultsToOpenState) {
            [_filterBar resetFilters:[NSPredicate predicateWithFormat:@"closed = NO"]];
        } else {
            [_filterBar resetFilters:nil];
        }
    }
    
    NSView *rightPane = [_splitView.subviews lastObject];
    if ([selectedItem viewController]) {
        NSViewController *vc = selectedItem.viewController;
        if (!vc.view.superview) {
            [rightPane setContentView:vc.view];
        }
        _searchItem.enabled = NO;
        _predicateItem.enabled = NO;
        _modeItem.enabled = NO;
    } else {
        _searchItem.enabled = YES;
        _predicateItem.enabled = YES;
        _modeItem.enabled = YES;
        _filterBar.basePredicate = selectedItem.predicate;
        [self updatePredicate];
    }

    if (selectedItem.identifier) {
        [[NSUserDefaults standardUserDefaults] setObject:selectedItem.identifier forKey:LastSelectedNodeDefaultsKey];
    }
    
    if (selectedItem.knobs.count > 0) {
        [_outlineView.animator expandItem:selectedItem];
    }
    [self walkNodes:^(OverviewNode *node) {
        if (node != selectedItem && (node.children.count == 0 && node.knobs.count > 0)) {
            [_outlineView.animator collapseItem:node];
        }
    }];
    
    [self updateTitle];
}

- (void)outlineViewItemDidExpand:(NSNotification *)notification {
    // Hacky workaround for ship://Problems/165 <Overview date knob can be visible without corresponding node being selected>
    OverviewNode *selectedItem = [_outlineView selectedItem];
    if (selectedItem.parent == nil) {
        [self walkNodes:^(OverviewNode *node) {
            if (node != selectedItem && (node.children.count == 0 && node.knobs.count > 0)) {
                [_outlineView.animator collapseItem:node];
            }
        }];
    }
    
    OverviewNode *node = notification.userInfo[@"NSObject"];
    if (node) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:[NSString stringWithFormat:@"%@.collapsed", node.identifier]];
    }
}

- (void)outlineViewItemDidCollapse:(NSNotification *)notification {
    OverviewNode *node = notification.userInfo[@"NSObject"];
    if (node) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:[NSString stringWithFormat:@"%@.collapsed", node.identifier]];
    }
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(nullable id)item proposedChildIndex:(NSInteger)index
{
    NSPasteboard *pb = [info draggingPasteboard];
    if (![NSString canReadIssueIdentifiersFromPasteboard:pb]) {
        return NSDragOperationNone;
    }
    
    OverviewNode *node = item;
    if (node.dropHandler) {
        return NSDragOperationCopy;
    } else {
        return NSDragOperationNone;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(nullable id)item childIndex:(NSInteger)index
{
    NSPasteboard *pb = [info draggingPasteboard];
    NSArray *identifiers = [NSString readIssueIdentifiersFromPasteboard:pb];
    
    OverviewNode *node = item;
    
    if (node.dropHandler && identifiers.count > 0) {
        node.dropHandler(identifiers);
        return YES;
    }
    
    return NO;
}

#pragma mark -

- (IBAction)newDocument:(id)sender {
    [[IssueDocumentController sharedDocumentController] newDocument:sender];
}

- (IBAction)searchItemChanged:(id)sender {
    [self updatePredicate];
}

+ (OverviewController *)defaultOverviewController {
    AppDelegate *d = (id)[NSApp delegate];
    return [d defaultOverviewController];
}

- (IBAction)showDownloads:(id)sender {
    [self expandAndSelectItem:_attachmentsNode];
    [[self window] makeKeyAndOrderFront:nil];
}

- (void)selectAllProblemsNode {
    [self expandAndSelectItem:_allProblemsNode];
}

- (IBAction)searchAllProblems:(id)sender {
    self.window.toolbar.visible = YES;
    [self selectAllProblemsNode];
    if (_modeItem.mode == ResultsViewModeChart) {
        [self showList:nil];
    }
    [_filterBar clearFilters];
    _searchItem.searchField.stringValue = @"";
    [[self window] makeFirstResponder:_searchItem.searchField];
}

- (IBAction)performFindPanelAction:(id)sender {
    if (_outlineView.selectedRow < 0) {
        [self selectAllProblemsNode];
    }
    [_searchItem.searchField selectText:sender];
    [[self window] makeFirstResponder:_searchItem.searchField];
}

- (IBAction)markAllNotificationsAsRead:(id)sender {
    [[DataStore activeStore] markAllIssuesAsReadWithCompletion:^(NSError *error) {
        if (error) {
            NSAlert *alert = [NSAlert new];
            alert.messageText = NSLocalizedString(@"Unable to mark notifications as read", nil);
            alert.informativeText = [error localizedDescription];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
            [alert beginSheetModalForWindow:[self window] completionHandler:nil];
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == self.window) {
        id firstResponder = self.window.firstResponder;
        if (firstResponder == _searchItem.searchField) {
            if (_outlineView.selectedRow < 0) {
                [self selectAllProblemsNode];
            }
        }
    } else if (object == [self activeResultsController]) {
        if ([keyPath isEqualToString:@"title"]) {
            [self updateTitle];
        }
    }
}

#pragma mark - NSSplitViewDelegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    if (splitView == _splitView) {
        if (dividerIndex == 0) {
            return 200.0;
        } else {
            return 500.0;
        }
    }
    return proposedMinimumPosition;
}
    
- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if (splitView == _splitView) {
        if (dividerIndex == 0) {
            ResultsController *active = [self activeResultsController];
            NSSize minSize = active.preferredMinimumSize;
            
            CGFloat totalWidth = splitView.frame.size.width;
            
            return MIN(500.0, totalWidth - minSize.width);
        }
    }
    return proposedMaximumPosition;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    if (splitView == _splitView) {
        return [[splitView subviews] indexOfObjectIdenticalTo:subview] == 0;
    } else {
        return NO;
    }
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)view {
    return [[splitView subviews] indexOfObjectIdenticalTo:view] == 1;
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    if (notification.object == _splitView) {
        [self updateSidebarItem];
    }
}

- (void)splitView:(NSSplitView *)splitView splitViewIsAnimating:(BOOL)animating {
    if (!animating) {
        [self updateSidebarItem];
    }
}

#pragma mark - FilterBarViewControllerDelegate

- (void)filterBar:(FilterBarViewController *)vc didUpdatePredicate:(NSPredicate *)newPredicate {
    [self updatePredicate];
}

#pragma mark - Query Actions

- (IBAction)editQuery:(id)sender {
    CustomQuery *query = [[sender menu] extras_representedObject];
    if (!query) {
        query = [[_outlineView selectedItem] representedObject];
    }
    
    if (![query isKindOfClass:[CustomQuery class]]) {
        return;
    }
    
    SearchSheet *sheet = [SearchSheet new];
    sheet.query = query;
    
    [sheet beginSheetModalForWindow:self.window completionHandler:nil];
}

- (IBAction)renameQuery:(id)sender {
    CustomQuery *query = [[sender menu] extras_representedObject];
    if (!query) return;
    
    [self selectItemsMatchingPredicate:[NSPredicate predicateWithFormat:@"representedObject = %@", query]];
    NSTableCellView *view = [_outlineView viewAtColumn:[_outlineView selectedColumn] row:[_outlineView selectedRow] makeIfNecessary:NO];
    [view.window makeFirstResponder:view.textField];
}

- (IBAction)removeQuery:(id)sender {
    CustomQuery *query = [[sender menu] extras_representedObject];
    if (!query) return;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to remove the query “%@”?", nil), query.title];
    alert.informativeText = NSLocalizedString(@"This action cannot be undone.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Remove", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [[DataStore activeStore] deleteQuery:query completion:^(NSArray *myQueries) { }];
        }
    }];
}

- (IBAction)copyQueryLink:(id)sender {
    CustomQuery *query = [[sender menu] extras_representedObject];
    if (!query) return;

    NSURL *URL = [query URL];
    NSString *title = [query URLAndTitle];
    
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb writeURL:URL string:title];
}

- (IBAction)commitRename:(id)sender {
    OverviewNode *node = [sender extras_representedObject];
    CustomQuery *query = [node representedObject];
    NSString *title = [sender stringValue];
    
    if ([[title trim] length] == 0) {
        [sender setStringValue:query.title];
    } else {
        query.title = title;
        [[DataStore activeStore] saveQuery:query completion:^(NSArray *myQueries) { }];
    }
}

- (void)textDidBeginEditing:(NSNotification *)notification {

}

- (void)textDidEndEditing:(NSNotification *)notification {
    id sender = [notification object];
    OverviewNode *node = [sender representedObject];
    CustomQuery *query = [node representedObject];
    [sender setStringValue:query.title];
}

- (void)openQuery:(CustomQuery *)query {
    // First, see if we already have a node for this.
    __block BOOL found = NO;
    [self walkNodes:^(OverviewNode *node) {
        if (!found && [node.representedObject isKindOfClass:[CustomQuery class]]) {
            CustomQuery *q = node.representedObject;
            if ([q.identifier isEqualToString:query.identifier]) {
                [self expandAndSelectItem:node];
                found = YES;
            }
        }
    }];
    
#if !INCOMPLETE
    if (!found) {
        self.nextNodeToSelect = query.identifier;
        [[DataStore activeStore] watchQuery:query completion:^(NSArray *myQueries) { }];
    }
#endif
}

- (IBAction)copyURL:(id)sender {
    id selectedItem = [_outlineView selectedItem];
    if ([[selectedItem representedObject] isKindOfClass:[CustomQuery class]]) {
        CustomQuery *query = [selectedItem representedObject];
        NSURL *URL = [query URL];
        NSString *title = [query URLAndTitle];
        
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb writeURL:URL string:title];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(showChart:)) {
        return _modeItem.chartEnabled;
    } else if (menuItem.action == @selector(showChartOptions:)) {
        return _modeItem.mode == ResultsViewModeChart;
    } else if (menuItem.action == @selector(copyURL:)) {
        id selectedItem = [_outlineView selectedItem];
        if ([[selectedItem representedObject] isKindOfClass:[CustomQuery class]]) {
            return YES;
        }
        return NO;
    } else if (menuItem.action == @selector(editQuery:)) {
        id selectedItem = [_outlineView selectedItem];
        id repr = [selectedItem representedObject];
        return [repr isKindOfClass:[CustomQuery class]] && [repr isMine];
    } else if (menuItem.action == @selector(copy:)) {
        return [[self activeResultsController] respondsToSelector:@selector(copy:)]
        && (![[self activeResultsController] respondsToSelector:@selector(validateMenuItem:)] || [[self activeResultsController] validateMenuItem:menuItem]);
    }
    return YES;
}
        
#pragma mark -

- (IBAction)showList:(id)sender {
    _modeItem.mode = ResultsViewModeList;
    [self changeResultsMode:sender];
}

- (IBAction)showChart:(id)sender {
    _modeItem.mode = ResultsViewModeChart;
    [self changeResultsMode:sender];
}

- (IBAction)showBrowser:(id)sender {
    _modeItem.mode = ResultsViewMode3Pane;
    [self changeResultsMode:sender];
}

- (IBAction)showChartOptions:(id)sender {
    [_chartController configure:sender];
}

- (IBAction)copy:(id)sender {
    if ([[self activeResultsController] respondsToSelector:@selector(copy:)]) {
        [(id)[self activeResultsController] copy:sender];
    }
}

#pragma mark -

- (IBAction)buildNewQuery:(id)sender {
    [self showPredicateEditor:sender];
}

- (IBAction)addNewMilestone:(id)sender {
    OverviewNode *node = [_outlineView selectedItem];
    id represented = node.representedObject;
    
    NSArray *initialRepos = nil;
    if ([represented isKindOfClass:[Repo class]]) {
        initialRepos = @[represented];
    } else if ([represented isKindOfClass:[Account class]]) {
        initialRepos = [[[DataStore activeStore] metadataStore] reposForOwner:represented];
    }
    
    NewMilestoneController *mc = [[NewMilestoneController alloc] initWithInitialRepos:initialRepos initialReposAreRequired:NO initialName:nil];
    [mc beginInWindow:self.window completion:nil];
}

#pragma mark -

- (IBAction)showWebhookWarning:(id)sender {
    OverviewNode *node = [sender extras_representedObject];
    NSString *message = nil;
    NSString *viewTitle = nil;
    NSURL *viewURL = nil;
    Account *owner = node.representedObject;
    NSString *webhost = [[[[[DataStore activeStore] auth] account] ghHost] stringByReplacingOccurrencesOfString:@"api." withString:@""];
    if ([owner isKindOfClass:[Org class]]) {
        message = [NSString stringWithFormat:NSLocalizedString(@"Ship was unable to install webhooks in the %@ organization. Without webhooks installed, Ship may take longer to reflect changes made on github.com.\n\nTo fix this, please ask a user with admin rights in the %@ organization to sign in with Ship.", @"Org Webhook Error"), owner.login, owner.login];
        viewTitle = NSLocalizedString(@"View Admins", nil);
        
        NSURLComponents *comps = [NSURLComponents new];
        comps.scheme = @"https";
        comps.host = webhost;
        comps.path = [NSString stringWithFormat:@"/orgs/%@/people", [owner.login stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]];
        comps.queryItemsDictionary = @{ @"utf8" : @"✓",
                                        @"query" : @"role:owner " };
        
        viewURL = comps.URL;
    } else if (![owner.identifier isEqual:[[User me] identifier]]) {
        message = [NSString stringWithFormat:NSLocalizedString(@"Ship was unable to install webhooks for %@. Without webhooks installed, Ship may take longer to reflect changes made on github.com.\n\nTo fix this, please ask %@ to sign in with Ship.", @"Other User Webhook Error"), owner.login, owner.login];
        viewTitle = NSLocalizedString(@"View Owner", nil);
        viewURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/%@", [owner.login stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]]];
    } else {
        message = NSLocalizedString(@"Ship was unable to install webhooks for your repositories. Without webhooks installed, Ship may take longer to reflect changes made on github.com.\n\nTo fix this, please check the webhooks and services settings for your repositories.", @"User Webhook Error");
    }
    
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Webhook Installation Failed", nil);
    alert.informativeText = message;
    
    alert.showsSuppressionButton = YES;
    alert.suppressionButton.title = NSLocalizedString(@"Hide this warning", nil);
    
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    
    if (viewURL && viewTitle) {
        [alert addButtonWithTitle:viewTitle];
    }
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertSecondButtonReturn) {
            [[NSWorkspace sharedWorkspace] openURL:viewURL];
        }
        if (alert.suppressionButton.state == NSOnState) {
            NSString *defaultsKey = [NSString stringWithFormat:@"WebhookWarningHidden.%@", owner.identifier];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:defaultsKey];
            
            NSInteger row = [_outlineView rowForItem:node];
            OverviewOwnerCellView *cell = [[_outlineView rowViewAtRow:row makeIfNecessary:NO] viewAtColumn:0];
            cell.warningWidth.constant = 0.0;
        }
    }];
}

#pragma mark -

- (NSArray<Issue *> *)selectedIssues {
    if (_modeItem.mode == ResultsViewModeList) {
        return [_searchResults selectedProblemSnapshots];
    } else if (_modeItem.mode == ResultsViewMode3Pane) {
        return [_threePaneController selectedProblemSnapshots];
    }
    return nil;
}

#pragma mark -

- (BOOL)isSidebarCollapsed {
    return [_splitView isSubviewCollapsed:[[_splitView subviews] firstObject]];
}

- (NSSize)minimumWindowSize {
    ResultsController *active = [self activeResultsController];
    NSSize minSize = active.preferredMinimumSize;
    
    CGFloat sidebarWidth = [self isSidebarCollapsed] ? 0.0 : _outlineView.frame.size.width;
    minSize.width += sidebarWidth;
    
    return minSize;
}

- (void)adjustWindowToMinimumSize {
    NSSize min = [self minimumWindowSize];
    
    NSRect frame = self.window.frame;
    
    frame.size.width = MAX(min.width, frame.size.width);
    frame.size.height = MAX(min.height, frame.size.height);
    
    [self.window setFrame:frame display:YES animate:YES];
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
    NSSize min = [self minimumWindowSize];
    
    frameSize.width = MAX(min.width, frameSize.width);
    frameSize.height = MAX(min.height, frameSize.height);
    
    return frameSize;
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect {
    if (_filterBar.window) {
        rect.origin.y += _filterBar.view.bounds.size.height;
    }
    return rect;
}

- (void)windowWillBeginSheet:(NSNotification *)notification {
    _filterBar.enabled = NO;
}

- (void)windowDidEndSheet:(NSNotification *)notification {
    _filterBar.enabled = YES;
}

- (IBAction)toggleSidebar:(id)sender {
    BOOL collapsed = [self isSidebarCollapsed];
    [_splitView setPosition:collapsed?240.0:0.0 ofDividerAtIndex:0 animated:YES];
    [self updateSidebarItem];
}

- (void)updateSidebarItem {
    BOOL collapsed = [self isSidebarCollapsed];
    _sidebarItem.on = !collapsed;
}

@end

@implementation OverviewOutlineView

- (void)setFrameSize:(NSSize)newSize {
    // be like Mail.app and add a bit of padding at the bottom
    newSize.height += 12.0;
    [super setFrameSize:newSize];
}

- (id)selectedItem {
    NSIndexSet *selected = [self selectedRowIndexes];
    if ([selected count]) {
        return [self itemAtRow:[selected firstIndex]];
    } else {
        return nil;
    }
}

- (NSRect)frameOfOutlineCellAtRow:(NSInteger)row {
    // Remove disclosure triangles for nodes whose only children are knobs.
    // The only way to expand these guys is to select them.
    id item = [self itemAtRow:row];
    if ([item isKindOfClass:[OverviewNode class]]) {
        OverviewNode *node = item;
        if (node.children.count == 0) {
            return NSZeroRect;
        }
    }
    return [super frameOfOutlineCellAtRow:row];
}

- (NSRect)frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row {
    NSRect frame = [super frameOfCellAtColumn:column row:row];
    id item = [self itemAtRow:row];
    if ([item isKindOfClass:[OverviewKnob class]]) {
        frame.origin.x -= 15.0;
        frame.size.width += 15.0;
    } else if ([item isKindOfClass:[OverviewNode class]] && [item icon] != nil) {
        frame.origin.x -= 6.0;
        frame.size.width += 6.0;
    }
    return frame;
}

- (void)keyDown:(NSEvent *)theEvent {
    if (self.selectedRow >= 0) {
        id item = [self itemAtRow:self.selectedRow];
        if ([item isKindOfClass:[OverviewNode class]]) {
            OverviewNode *node = item;
            if (node.knobs.count > 0) {
                if ([theEvent isArrowLeft]) {
                    [[node.knobs firstObject] moveBackward:self];
                    return;
                } else if ([theEvent isArrowRight]) {
                    [[node.knobs firstObject] moveForward:self];
                    return;
                }
            }
        }
    }
    [super keyDown:theEvent];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent {
    NSPoint pt = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    NSInteger idx = [self rowAtPoint:pt];
    id item = [self itemAtRow:idx];
    if ([item isKindOfClass:[OverviewNode class]]) {
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:idx] byExtendingSelection:NO];
        return [item menu];
    }
    return nil;
}

- (BOOL)validateProposedFirstResponder:(NSResponder *)responder forEvent:(NSEvent *)event {
    if ([responder isKindOfClass:[NSTextField class]] && ([event type] == NSRightMouseDown || [event type] == NSRightMouseUp)) {
        return NO;
    }
    return [super validateProposedFirstResponder:responder forEvent:event];
}

@end

@implementation OverviewProgressIndicator

- (void)_updateTooltip {
    self.toolTip = [NSString localizedStringWithFormat:NSLocalizedString(@"%.0f%% Complete. %td Open. %td Closed.", nil), _doubleValue * 100.0, _openCount, _closedCount];
}

- (void)updateTooltip {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateTooltip) object:nil];
    [self performSelector:@selector(_updateTooltip) withObject:nil afterDelay:0];
}

- (void)setClosedCount:(NSInteger)closedCount {
    _closedCount = closedCount;
    [self updateTooltip];
}

- (void)setOpenCount:(NSInteger)openCount {
    _openCount = openCount;
    [self updateTooltip];
}

- (void)setDoubleValue:(double)doubleValue {
    _doubleValue = doubleValue;
    [self updateTooltip];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    NSColor *fillColor = [NSColor colorWithWhite:0.467 alpha:1.0];
    NSColor *bgColor = [[NSColor blackColor] colorWithAlphaComponent:0.1];
    
    CGRect b = self.bounds;

    CGRect bgRect = CGRectMake(1.0, 1.0, b.size.width - 2.0, b.size.height - 2.0);
    CGFloat bgRadius = bgRect.size.height / 2.0;
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:bgRect xRadius:bgRadius yRadius:bgRadius];
    
    [bgColor set];
    [bgPath fill];

    // Inset 0.5 so the stroke doesn't get split between between pixels.
    CGRect fillRect = CGRectInset(bgRect, 0.5, 0.5);
    CGFloat fillRadius = fillRect.size.height / 2.0;
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:fillRadius yRadius:fillRadius];

    [fillColor set];
    fillPath.lineWidth = 1.0;

    [fillPath stroke];

    CGRect clipRect;
    clipRect.size.width = round((b.size.width - 2.0) * _doubleValue);
    clipRect.origin.x = 1.0;
    clipRect.origin.y = 0.0;
    clipRect.size.height = b.size.height;
    
    NSBezierPath *clip = [NSBezierPath bezierPathWithRect:clipRect];
    [clip addClip];
    
    [fillPath fill];
}

@end

@implementation OverviewCellView

@end

@implementation OverviewCountCellView

@end

@implementation OverviewOwnerCellView

@end

@implementation OverviewMilestoneCellView

@end

@implementation OverviewWindow

- (void)toggleToolbarShown:(id)sender {
    // Default NSWindow implementation toggles all toolbars with the same identifier.
    // We don't want this.
    // See ship://Problems/230 <Hide toolbar hides all the toolbars>
    
    self.toolbar.visible = !self.toolbar.visible;
}

@end

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

#import "IssueDocumentController.h"

//#import "OutboxViewController.h"
//#import "AttachmentProgressViewController.h"
//#import "SearchEditorViewController.h"
//#import "CustomQuery.h"
//#import "SaveSearchController.h"
//#import "ProblemProgressController.h"

#import <QuartzCore/QuartzCore.h>

static NSString *const LastSelectedNodeDefaultsKey = @"OverviewLastSelectedNode";
static NSString *const LastSelectedModeDefaultsKey = @"OverviewLastSelectedMode";

@interface OverviewWindow : NetworkStateWindow

@end

@interface OverviewOutlineView : NSOutlineView

- (id)selectedItem;

@end

@interface OverviewCellView : NSTableCellView

@property IBOutlet NSButton *countButton;
@property IBOutlet Sparkline *sparkline;

@property IBOutlet NSLayoutConstraint *sparklineWidth;

@end

#define SPARKLINE_WIDTH 20.0

@interface SearchSplit : NSSplitView

@end

@interface OverviewController () <NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate, NSWindowDelegate, FilterBarViewControllerDelegate,
#if !INCOMPLETE
SearchEditorViewControllerDelegate,
#endif
NSTextFieldDelegate>

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

#if !INCOMPLETE
@property (strong) SearchEditorViewController *predicateEditor;
#endif
@property (strong) SearchSplit *searchSplit; // horizontal split between predicateEditor and searchResults

@property (strong) IBOutlet NSPopUpButton *addButton;

@property NSArray *outlineRoots;

@property OverviewNode *allProblemsNode;
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
    _searchSplit.delegate = nil;
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
    [self.window addTitlebarAccessoryViewController:_filterBar];
    
    NSImage *sidebarImage = [NSImage sidebarIcon];
    _sidebarItem.buttonImage = sidebarImage;
    _sidebarItem.toolTip = NSLocalizedString(@"Toggle Sidebar", nil);
    _sidebarItem.trackingMode = NSSegmentSwitchTrackingSelectAny;
    
    _createNewItem.buttonImage = [NSImage imageNamed:@"NSToolbarCompose"];
    _createNewItem.toolTip = NSLocalizedString(@"New Problem ⌘N", nil);
    
    _predicateItem.buttonImage = [NSImage advancedSearchIcon];
    _predicateItem.toolTip = NSLocalizedString(@"Refine Search ⌥⌘F", nil);
    _predicateItem.trackingMode = NSSegmentSwitchTrackingSelectAny;
    
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
    
    NSView *rightPane = [_splitView.subviews lastObject];
    
    _searchSplit = [[SearchSplit alloc] initWithFrame:rightPane.bounds];
    _searchSplit.vertical = NO;
    _searchSplit.delegate = self;
    _searchSplit.dividerStyle = NSSplitViewDividerStyleThin;
    [_searchSplit addSubview:[NSView new]];
    [_searchSplit addSubview:[NSView new]];
    
#if !INCOMPLETE
    _predicateEditor = [SearchEditorViewController new];
    _predicateEditor.delegate = self;
#endif
    
    [_searchSplit setPosition:0.0 ofDividerAtIndex:0];
    
    ResultsViewMode initialMode = [[Defaults defaults] integerForKey:LastSelectedModeDefaultsKey fallback:ResultsViewMode3Pane];
    _modeItem.mode = initialMode;
    [self changeResultsMode:nil];
    
    [rightPane setContentView:_searchSplit];
    
    [_splitView setPosition:240.0 ofDividerAtIndex:0];
    
    _outlineView.floatsGroupRows = NO;
    
    self.window.frameAutosaveName = @"Overview";
    _splitView.autosaveName = @"OverviewSplit";
    
    CGFloat dividerPos = [[[_splitView subviews] objectAtIndex:0] frame].size.width;
    if (dividerPos > 0.0 && dividerPos < 180.0) {
        [_splitView setPosition:240.0 ofDividerAtIndex:0];
        [self updateSidebarItem];
    }

    [self buildOutline];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataChanged:) name:DataStoreDidUpdateMetadataNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataStoreChanged:) name:DataStoreActiveDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(queriesChanged:) name:DataStoreDidUpdateMyQueriesNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(problemsChanged:) name:DataStoreDidUpdateProblemsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialSyncStarted:) name:DataStoreWillBeginInitialMetadataSync object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialSyncEnded:) name:DataStoreDidEndInitialMetadataSync object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outboxChanged:) name:DataStoreDidUpdateOutboxNotification object:nil];
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

#if !INCOMPLETE
- (NSMenu *)menuForCustomQuery:(CustomQuery *)query {
    NSMenu *menu = [NSMenu new];
    menu.extras_representedObject = query;
    [menu addItemWithTitle:NSLocalizedString(@"Rename Query", nil) action:@selector(renameQuery:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Remove Query", nil) action:@selector(removeQuery:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy Link", nil) action:@selector(copyQueryLink:) keyEquivalent:@""];
    return menu;
}

- (NSMenu *)menuForBookmarkedQuery:(CustomQuery *)query {
    NSMenu *menu = [NSMenu new];
    menu.extras_representedObject = query;
    [menu addItemWithTitle:NSLocalizedString(@"Remove Query", nil) action:@selector(removeBookmarkedQuery:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy Link", nil) action:@selector(copyQueryLink:) keyEquivalent:@""];
    return menu;
}

- (NSMenu *)menuForRecentQuery:(CustomQuery *)query {
    NSMenu *menu = [NSMenu new];
    menu.extras_representedObject = query;
    [menu addItemWithTitle:NSLocalizedString(@"Bookmark Query", nil) action:@selector(bookmarkQuery:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Remove Query", nil) action:@selector(removeRecentQuery:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Copy Link", nil) action:@selector(copyQueryLink:) keyEquivalent:@""];
    return menu;
}
#endif

- (void)buildOutline {
    NSString *savedIdentifier = nil;
    if (_nextNodeToSelect) {
        savedIdentifier = _nextNodeToSelect;
#if !INCOMPLETE
    } else if ([[_outlineView selectedItem] identifier]) {
        savedIdentifier = [[_outlineView selectedItem] identifier];
#endif
    } else {
        NSString *lastViewedIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:LastSelectedNodeDefaultsKey];
        savedIdentifier = lastViewedIdentifier ?: @"MyOpenProblems";
    }
    _nextNodeToSelect = nil;
    
    NSMutableDictionary *oldCounts = nil;
    if (_outlineRoots) {
        oldCounts = [NSMutableDictionary dictionary];
        [self walkNodes:^(OverviewNode *node) {
            if (node.count != NSNotFound) {
                oldCounts[node.identifier] = @(node.count);
            }
        }];
    }
    
    NSMutableArray *roots = [NSMutableArray array];
    
#if 0
    OverviewNode *inbox = [OverviewNode new];
    inbox.title = NSLocalizedString(@"Unread", nil);
    [roots addObject:inbox];
    
    OverviewNode *inboxToMe = [OverviewNode new];
    inboxToMe.title = NSLocalizedString(@"Assigned To Me", nil);
    inboxToMe.predicate = [NSPredicate predicateWithFormat:@"assignee.identifier = %@ AND (state = nil OR state.resolved = NO) AND read = NO", [[User me] identifier]];
    inboxToMe.showCount = YES;
    inboxToMe.allowChart = NO;
    inboxToMe.icon = [NSImage overviewIconNamed:@"928-inbox-files-selected"];
    [inbox addChild:inboxToMe];
    
    OverviewNode *inboxWatching = [OverviewNode new];
    inboxWatching.title = NSLocalizedString(@"I'm Watching", nil);
    inboxWatching.predicate = [NSPredicate predicateWithFormat:@"watching = YES AND read = NO AND (state = nil OR state.resolved = NO)"];
    inboxWatching.showCount = YES;
    inboxWatching.allowChart = NO;
    inboxWatching.icon = [NSImage overviewIconNamed:@"878-binoculars-selected"];
    [inbox addChild:inboxWatching];
#endif
    
    OverviewNode *milestonesRoot = [OverviewNode new];
//    milestonesRoot.representedObject = _milestoneMap;
    milestonesRoot.title = NSLocalizedString(@"Active Milestones", nil);
    [roots addObject:milestonesRoot];
    
    MetadataStore *metadata = [[DataStore activeStore] metadataStore];
    
    NSImage *milestoneIcon = [NSImage overviewIconNamed:@"563-calendar"];
    for (NSString *milestone in [metadata mergedMilestoneNames]) {
        OverviewNode *node = [OverviewNode new];
        node.representedObject = milestone;
        node.title = milestone;
        node.predicate = [NSPredicate predicateWithFormat:@"milestone.title = %@", milestone];
//        node.toolTip = [milestone localizedDateRange];
        node.icon = milestoneIcon;
        [milestonesRoot addChild:node];
        
        OverviewNode *openAll = [OverviewNode new];
        openAll.representedObject = milestone;
        openAll.title = NSLocalizedString(@"Open : All", nil);
        openAll.path = [NSString stringWithFormat:@"%@ : %@", milestone, openAll.title];
        openAll.showCount = YES;
        openAll.predicate = [NSPredicate predicateWithFormat:@"milestone.title = %@ AND closed = NO", milestone];
        openAll.icon = milestoneIcon;
        [node addChild:openAll];
        
        OverviewNode *openMe = [OverviewNode new];
        openMe.representedObject = milestone;
        openMe.title = NSLocalizedString(@"Open : Mine", nil);
        openMe.path = [NSString stringWithFormat:@"%@ : %@", milestone, openMe.title];
        openMe.showCount = YES;
        openMe.predicate = [NSPredicate predicateWithFormat:@"milestone.title = %@ AND closed = NO AND assignee.identifier = %@", milestone, [User me].identifier];
        openMe.icon = milestoneIcon;
        [node addChild:openMe];
        
        OverviewNode *closed = [OverviewNode new];
        closed.representedObject = milestone;
        closed.title = NSLocalizedString(@"Closed", nil);
        closed.path = [NSString stringWithFormat:@"%@ : %@", milestone, closed.title];
        closed.predicate = [NSPredicate predicateWithFormat:@"milestone.title = %@ AND closed = YES", milestone];
        closed.icon = milestoneIcon;
        [node addChild:closed];
    }
    
#if 0
    OverviewNode *backlog = [OverviewNode new];
    backlog.title = NSLocalizedString(@"Backlog", nil);
    [roots addObject:backlog];
    
    OverviewNode *backlogAll = [OverviewNode new];
    backlogAll.title = NSLocalizedString(@"All Backlog", nil);
    backlogAll.path = NSLocalizedString(@"Backlog : All", nil);
    backlogAll.showCount = YES;
    backlogAll.predicate = [NSPredicate predicateWithFormat:@"milestone.identifier = nil AND closed = NO"];
    backlogAll.icon = [NSImage overviewIconNamed:@"832-stack-1"];
    [backlog addChild:backlogAll];
    
    OverviewNode *backlogMine = [OverviewNode new];
    backlogMine.title = NSLocalizedString(@"My Backlog", nil);
    backlogMine.path = NSLocalizedString(@"Backlog : Mine", nil);
    backlogMine.showCount = YES;
    backlogMine.predicate = [NSPredicate predicateWithFormat:@"milestone.identifier = nil AND closed = NO AND assignee.identifier = %@", [[User me] identifier]];
    backlogMine.icon = [NSImage overviewIconNamed:@"832-stack-1-selected"];
    [backlog addChild:backlogMine];
#endif
    
    // List repos
    BOOL multipleOwners = [[metadata repoOwners] count] > 1;
    
    for (Account *repoOwner in [metadata repoOwners]) {
        
        for (Repo *repo in [metadata reposForOwner:repoOwner]) {
            OverviewNode *repoNode = [OverviewNode new];
            repoNode.title = multipleOwners ? repo.fullName : repo.name;
            [roots addObject:repoNode];
            
            NSPredicate *repoPredicate = [NSPredicate predicateWithFormat:@"repository.fullName = %@", repo.fullName];
            
            OverviewNode *repoOpen = [OverviewNode new];
            repoOpen.title = NSLocalizedString(@"Open : All", nil);
            repoOpen.path = [NSString stringWithFormat:@"%@ : %@", repoNode.title, repoOpen.title];
            repoOpen.predicate = [repoPredicate and:[NSPredicate predicateWithFormat:@"closed = NO"]];
            repoOpen.icon = [NSImage overviewIconNamed:@"961-book-32"];
            repoOpen.showCount = YES;
            [repoNode addChild:repoOpen];
            
            OverviewNode *repoOpenMine = [OverviewNode new];
            repoOpenMine.title = NSLocalizedString(@"Open : Mine", nil);
            repoOpenMine.path = [NSString stringWithFormat:@"%@ : %@", repoNode.title, repoOpenMine.title];
            repoOpenMine.predicate = [repoOpen.predicate and:[NSPredicate predicateWithFormat:@"assignee.identifier = %@", [[User me] identifier]]];
            repoOpenMine.icon = [NSImage overviewIconNamed:@"961-book-32"];
            repoOpenMine.showCount = YES;
            [repoNode addChild:repoOpenMine];
            
            for (Milestone *milestone in [metadata activeMilestonesForRepo:repo]) {
                OverviewNode *rmNode = [OverviewNode new];
                rmNode.title = milestone.title;
                rmNode.path = [NSString stringWithFormat:@"%@ : %@", repoNode.title, rmNode.title];
                rmNode.showCount = YES;
                rmNode.predicate = [repoOpen.predicate and:[NSPredicate predicateWithFormat:@"milestone.identifier = %@", milestone.identifier]];
                rmNode.icon = milestoneIcon;
                [repoNode addChild:rmNode];
                
                OverviewNode *rmMineNode = [OverviewNode new];
                rmMineNode.showCount = YES;
                rmMineNode.title = [NSString stringWithFormat:NSLocalizedString(@"%@ : Mine", nil), milestone.title];
                rmMineNode.path = [NSString stringWithFormat:@"%@ : %@", repoNode.title, rmMineNode.title];
                rmMineNode.predicate = [repoOpenMine.predicate and:[NSPredicate predicateWithFormat:@"milestone.identifier = %@", milestone.identifier]];
                rmMineNode.icon = milestoneIcon;
                [rmNode addChild:rmMineNode];
                
                
            }
            
        }
    }
    
    NSImage *queryIcon = [NSImage overviewIconNamed:@"666-gear2"];
    OverviewNode *queriesRoot = [OverviewNode new];
    queriesRoot.title = NSLocalizedString(@"Queries", nil);
    [roots addObject:queriesRoot];
    
    OverviewNode *recentlyCreated = [OverviewNode new];
    recentlyCreated.title = NSLocalizedString(@"Recently Created", nil);
    DateKnob *recentlyCreatedDateKnob = [DateKnob knobWithDefaultsIdentifier:@"recentlyCreated"];
    [recentlyCreated addKnob:recentlyCreatedDateKnob];
    recentlyCreated.predicateBuilder = ^{
        NSTimeInterval interval = -(recentlyCreatedDateKnob.daysAgo * 24 * 60 * 60);
        NSDate *then = [[NSDate date] dateByAddingTimeInterval:interval];
        return [NSPredicate predicateWithFormat:@"createdAt > %@", then];
    };
    recentlyCreated.target = self;
    recentlyCreated.action = @selector(nodeUpdatedPredicate:);
    recentlyCreated.icon = queryIcon;
    [queriesRoot addChild:recentlyCreated];
    
    OverviewNode *recentlyCreatedByMe = [OverviewNode new];
    recentlyCreatedByMe.title = NSLocalizedString(@"Recently Created By Me", nil);
    DateKnob *recentlyCreatedByMeDateKnob = [DateKnob knobWithDefaultsIdentifier:@"recentlyCreatedByMe"];
    [recentlyCreatedByMe addKnob:recentlyCreatedByMeDateKnob];
    recentlyCreatedByMe.predicateBuilder = ^{
        NSTimeInterval interval = -(recentlyCreatedByMeDateKnob.daysAgo * 24 * 60 * 60);
        NSDate *then = [[NSDate date] dateByAddingTimeInterval:interval];
        return [NSPredicate predicateWithFormat:@"createdAt > %@ AND originator.identifier = %@", then, [[User me] identifier]];
    };
    recentlyCreatedByMe.target = self;
    recentlyCreatedByMe.action = @selector(nodeUpdatedPredicate:);
    recentlyCreatedByMe.icon = queryIcon;
    [queriesRoot addChild:recentlyCreatedByMe];
    
    OverviewNode *recentlyModified = [OverviewNode new];
    recentlyModified.title = NSLocalizedString(@"Recently Modified", nil);
    DateKnob *recentlyModifiedDateKnob = [DateKnob knobWithDefaultsIdentifier:@"recentlyModified"];
    [recentlyModified addKnob:recentlyModifiedDateKnob];
    recentlyModified.predicateBuilder = ^{
        NSTimeInterval interval = -(recentlyModifiedDateKnob.daysAgo * 24 * 60 * 60);
        NSDate *then = [[NSDate date] dateByAddingTimeInterval:interval];
        return [NSPredicate predicateWithFormat:@"updatedAt > %@", then];
    };
    recentlyModified.target = self;
    recentlyModified.action = @selector(nodeUpdatedPredicate:);
    recentlyModified.icon = queryIcon;
    [queriesRoot addChild:recentlyModified];

#if 0
    OverviewNode *recentlyModifiedByMe = [OverviewNode new];
    recentlyModifiedByMe.title = NSLocalizedString(@"Recently Modified By Me", nil);
    DateKnob *recentlyModifiedByMeDateKnob = [DateKnob knobWithDefaultsIdentifier:@"recentlyModifiedByMe"];
    [recentlyModifiedByMe addKnob:recentlyModifiedByMeDateKnob];
    recentlyModifiedByMe.predicateBuilder = ^{
        NSTimeInterval interval = -(recentlyModifiedByMeDateKnob.daysAgo * 24 * 60 * 60);
        NSDate *then = [[NSDate date] dateByAddingTimeInterval:interval];
        return [NSPredicate predicateWithFormat:@"SUBQUERY(history, $h, $h.modificationDate > %@ AND $h.modifier.identifier = %@).@count > 0", then, [[User me] identifier]];
    };
    recentlyModifiedByMe.target = self;
    recentlyModifiedByMe.action = @selector(nodeUpdatedPredicate:);
    recentlyModifiedByMe.icon = queryIcon;
    [queriesRoot addChild:recentlyModifiedByMe];
#endif
    
    OverviewNode *openToMe = [OverviewNode new];
    openToMe.title = NSLocalizedString(@"My Open Problems", nil);
    openToMe.identifier = @"MyOpenProblems";
    openToMe.predicate = [NSPredicate predicateWithFormat:@"assignee.identifier = %@ AND closed = NO", [[User me] identifier]];
    openToMe.icon = queryIcon;
    [queriesRoot addChild:openToMe];
    
    OverviewNode *allProblems = _allProblemsNode = [OverviewNode new];
    allProblems.title = NSLocalizedString(@"All Problems", nil);
    allProblems.predicate = [NSPredicate predicateWithFormat:@"YES = YES"];
    allProblems.icon = queryIcon;
    [queriesRoot addChild:allProblems];
    
    OverviewNode *allOpenProblems = [OverviewNode new];
    allOpenProblems.title = NSLocalizedString(@"All Open Problems", nil);
    allOpenProblems.predicate = [NSPredicate predicateWithFormat:@"closed = NO"];
    allOpenProblems.icon = queryIcon;
    [queriesRoot addChild:allOpenProblems];
    
#if !INCOMPLETE
    NSArray *queries = [[DataStore activeStore] myQueries];
    NSString *myIdentifier = [[User me] identifier];
    NSArray *myQueries = [queries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"authorIdentifier = %@", myIdentifier]];
    NSArray *bookmarkedQueries = [queries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"authorIdentifier != %@ AND watchDate == nil", myIdentifier]];
    NSArray *recentQueries = [queries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"authorIdentifier != %@ && watchDate != nil", myIdentifier]];
    if ([myQueries count] > 0) {
        myQueries = [myQueries sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES comparator:[NSString comparatorWithOptions:NSNumericSearch|NSCaseInsensitiveSearch]]]];
        OverviewNode *myQueriesRoot = [OverviewNode new];
        myQueriesRoot.title = NSLocalizedString(@"My Queries", nil);
        [roots addObject:myQueriesRoot];
        
        for (CustomQuery *query in myQueries) {
            OverviewNode *queryNode = [OverviewNode new];
            queryNode.title = query.title;
            queryNode.representedObject = query;
            queryNode.predicate = query.predicate;
            queryNode.identifier = query.identifier;
            queryNode.menu = [self menuForCustomQuery:query];
            queryNode.titleEditable = YES;
            queryNode.showCount = YES;
            queryNode.icon = queryIcon;
            [myQueriesRoot addChild:queryNode];
        }
    }
    if ([bookmarkedQueries count] > 0) {
        bookmarkedQueries = [bookmarkedQueries sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES comparator:[NSString comparatorWithOptions:NSNumericSearch|NSCaseInsensitiveSearch]]]];
        OverviewNode *bookmarksRoot = [OverviewNode new];
        bookmarksRoot.title = NSLocalizedString(@"Bookmarked Queries", nil);
        [roots addObject:bookmarksRoot];
        
        for (CustomQuery *query in bookmarkedQueries) {
            OverviewNode *queryNode = [OverviewNode new];
            queryNode.title = query.titleWithAuthor;
            queryNode.representedObject = query;
            queryNode.predicate = query.predicate;
            queryNode.identifier = query.identifier;
            queryNode.menu = [self menuForBookmarkedQuery:query];
            queryNode.showCount = YES;
            queryNode.icon = queryIcon;
            [bookmarksRoot addChild:queryNode];
        }
    }
    if ([recentQueries count] > 0) {
        recentQueries = [recentQueries sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES comparator:[NSString comparatorWithOptions:NSNumericSearch|NSCaseInsensitiveSearch]]]];
        OverviewNode *recentsRoot = [OverviewNode new];
        recentsRoot.title = NSLocalizedString(@"Recent Queries", nil);
        [roots addObject:recentsRoot];
        
        for (CustomQuery *query in recentQueries) {
            OverviewNode *queryNode = [OverviewNode new];
            queryNode.title = query.titleWithAuthor;
            queryNode.representedObject = query;
            queryNode.predicate = query.predicate;
            queryNode.identifier = query.identifier;
            queryNode.menu = [self menuForRecentQuery:query];
            queryNode.showCount = YES;
            queryNode.icon = queryIcon;
            [recentsRoot addChild:queryNode];
        }
    }
#endif
    
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
    
    _outlineRoots = roots;
    
    if (oldCounts) {
        [self walkNodes:^(OverviewNode *node) {
            NSNumber *count = oldCounts[node.identifier];
            if (count && node.showCount) {
                node.count = count.unsignedIntegerValue;
            }
        }];
    }
    
    [_outlineView reloadData];
    [self expandDefault];
    
    if (savedIdentifier) {
        [self selectItemsMatchingPredicate:[NSPredicate predicateWithFormat:@"identifier = %@", savedIdentifier]];
    }
    
    [self updateCounts:nil];
}

- (void)updateCount:(OverviewNode *)node {
    void (^updateCount)(NSUInteger) = ^(NSUInteger count) {
        if (node.count != count) {
            node.count = count;
            NSInteger row = [_outlineView rowForItem:node];
            if (row >= 0) {
                OverviewCellView *view = [[_outlineView rowViewAtRow:row makeIfNecessary:NO] viewAtColumn:0];
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
        [[DataStore activeStore] countIssuesMatchingPredicate:node.predicate completion:^(NSUInteger count, NSError *error) {
            updateCount(count);
        }];
#if 0
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"sparklines"]
            && [[DataStore activeStore] predicateCanBeUsedForTimeSeries:node.predicate])
        {
            NSDate *end = [NSDate date];
            NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
            NSDate *start = [calendar dateByAddingUnit:NSCalendarUnitDay value:-5 toDate:end options:0];

            [[DataStore activeStore] timeSeriesMatchingPredicate:node.predicate startDate:start endDate:end completion:^(TimeSeries *series) {
                [series generateIntervalsWithCalendarUnit:NSCalendarUnitDay];
                NSArray *values = [series.intervals arrayByMappingObjects:^id(id obj) {
                    return @([[obj latestRecords] count]);
                }];
                node.sparkValues = values;
                NSInteger row = [_outlineView rowForItem:node];
                if (row >= 0) {
                    OverviewCellView *view = [[_outlineView rowViewAtRow:row makeIfNecessary:NO] viewAtColumn:0];
                    if (view) {
                        Sparkline *spark = view.sparkline;
                        spark.values = values;
                        view.sparklineWidth.constant = SPARKLINE_WIDTH;
                    }
                }
            }];
        }
#endif
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
    BOOL editingPredicate = _predicateItem.on;
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
    if ([indexes count] > 0 && editingPredicate) {
        _predicateItem.on = YES;
        [self togglePredicateEditor:_predicateItem];
    }
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
#if !INCOMPLETE
    id selectedItem = [_outlineView selectedItem];
    NSPredicate *predicate = nil;
    if (_predicateItem.on) {
        predicate = [_predicateEditor predicate];
    } else if (selectedItem) {
        predicate = [selectedItem predicate];
    }
    NSString *title = [[_searchItem.searchField stringValue] trim];
    NSInteger number = [title isDigits] ? [title integerValue] : 0;
    NSPredicate *searchPredicate = [title length] > 0 ? [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@", title] : nil;
    if (number != 0) {
        searchPredicate = [searchPredicate or:[NSPredicate predicateWithFormat:@"identifier = %ld", (long)number]];
    }
    if (predicate && searchPredicate) {
        predicate = [predicate and:searchPredicate];
    } else if (searchPredicate) {
        predicate = searchPredicate;
    }
    
    _modeItem.chartEnabled = (selectedItem == nil || [selectedItem allowChart]) && [[DataStore activeStore] predicateCanBeUsedForTimeSeries:predicate];
    
    [[self activeResultsController] setPredicate:predicate];
    [self updateCount:selectedItem];
#else
    id selectedItem = [_outlineView selectedItem];
    NSPredicate *predicate = nil;
    predicate = [selectedItem predicate];
    
    NSPredicate *filterPredicate = _filterBar.predicate;
    
    NSString *title = [[_searchItem.searchField stringValue] trim];
    NSInteger number = [title isDigits] ? [title integerValue] : 0;
    NSPredicate *searchPredicate = [title length] > 0 ? [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@", title] : nil;
    if (number != 0) {
        searchPredicate = [searchPredicate or:[NSPredicate predicateWithFormat:@"identifier = %ld", (long)number]];
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
    
    [[self activeResultsController] setPredicate:predicate];
    [self updateCount:selectedItem];
#endif
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
        if (_predicateItem.on && [resultsTitle length] > 0) {
            self.window.title = [NSString localizedStringWithFormat:NSLocalizedString(@"Overview : %@", nil), resultsTitle];
        } else {
            self.window.title = NSLocalizedString(@"Overview", nil);
        }
    } else {
        if (!selectedItem.viewController && [resultsTitle length] > 0) {
            self.window.title = [NSString localizedStringWithFormat:NSLocalizedString(@"Overview : %@ : %@", nil), selectedItem.path, resultsTitle];
        } else {
            self.window.title = [NSString stringWithFormat:NSLocalizedString(@"Overview : %@", nil), selectedItem.path];
        }
    }
}

#pragma mark -

- (IBAction)togglePredicateEditor:(id)sender {
#if !INCOMPLETE
    if (_predicateItem.on) {
        OverviewNode *node = [_outlineView selectedItem];
        if ([node isKindOfClass:[OverviewNode class]] && [[node representedObject] isKindOfClass:[CustomQuery class]]) {
            [_predicateEditor setPredicate:[node predicate]];
        } else {
            [_predicateEditor reset];
            [_outlineView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
        }
    }
    [self updateSearchSplit];
    [self updatePredicate];
#endif
}

- (CGFloat)heightForPredicateEditor {
#if !INCOMPLETE
    if (_predicateItem.on) {
        CGFloat height = [_predicateEditor fullHeight];
        height = MIN(height, round(_searchSplit.bounds.size.height * 0.6));
        return height;
    } else {
        return 0.0;
    }
#else
    return 0.0;
#endif
}

- (void)updateSearchSplit {
#if !INCOMPLETE
    if (_predicateItem.on) {
        [_searchSplit setPosition:[self heightForPredicateEditor] ofDividerAtIndex:0];
        [[[_searchSplit subviews] firstObject] setContentView:_predicateEditor.view];
    } else {
        [[[_searchSplit subviews] firstObject] setSubviews:@[]];
        [_searchSplit setPosition:0.0 ofDividerAtIndex:0];
    }
#endif
}

#pragma mark -

- (IBAction)changeResultsMode:(id)sender {
    [[Defaults defaults] setInteger:_modeItem.mode forKey:LastSelectedModeDefaultsKey];
    [[_searchSplit subviews][1] setContentView:[[self activeResultsController] view]];
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
        OverviewCellView *cell = [outlineView makeViewWithIdentifier:@"Label" owner:self];
        NSButton *countButton = cell.countButton;
        Sparkline *sparkline = cell.sparkline;
        if (node.count == NSNotFound) {
            countButton.hidden = YES;
            countButton.title = @"";
            cell.sparklineWidth.constant = 0.0;
        } else {
            countButton.title = [NSString localizedStringWithFormat:@"%tu", node.count];
            countButton.hidden = NO;
            if ([node.sparkValues count]) {
                sparkline.values = node.sparkValues;
                cell.sparklineWidth.constant = SPARKLINE_WIDTH;
            } else {
                cell.sparklineWidth.constant = 0.0;
            }
        }
        cell.imageView.image = node.icon;
        cell.textField.stringValue = node.title;
        cell.menu = node.menu;
        cell.textField.editable = node.titleEditable;
        cell.textField.target = self;
#if !INCOMPLETE
        cell.textField.action = @selector(commitRename:);
#endif
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
    if (!_nodeSelectionProgrammaticallyInitiated) {
        [_searchItem.searchField setStringValue:@""];
        [_filterBar clearFilters];
    }
    OverviewNode *selectedItem = [_outlineView selectedItem];
    
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
        if (!_searchSplit.superview) {
            [rightPane setContentView:_searchSplit];
            [self updateSearchSplit];
        }
        if (selectedItem && _predicateItem.on) {
            _predicateItem.on = NO;
            [self updateSearchSplit];
        }
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
    } else if (splitView == _searchSplit) {
        if (_predicateItem.on) {
            if (dividerIndex == 0) {
                return [self heightForPredicateEditor];
            }
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
    } else if (splitView == _searchSplit) {
        if (_predicateItem.on) {
            if (dividerIndex == 0) {
                return [self heightForPredicateEditor];
            }
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

#pragma mark - SearchEditorViewControllerDelegate

#if !INCOMPLETE
- (void)searchEditorViewControllerDidChangeFullHeight:(SearchEditorViewController *)vc
{
    if (_predicateItem.on) {
        [_searchSplit setPosition:[self heightForPredicateEditor] ofDividerAtIndex:0 animated:NO];
    }

}

- (void)searchEditorViewControllerDidChangePredicate:(SearchEditorViewController *)vc {
    if (_predicateItem.on) {
        [self updatePredicate];
        OverviewNode *node = [_outlineView selectedItem];
        CustomQuery *query = [node representedObject];
        if ([query isKindOfClass:[CustomQuery class]]) {
            if (query.watching && ![query.authorIdentifier isEqualToString:[[User me] identifier]]) {
                // If you edit the predicate and it's a shared one, deselect it.
                [_outlineView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
            }
        }
    }
}

- (void)searchEditorViewControllerSaveAsPredicate:(SearchEditorViewController *)vc {
    OverviewNode *node = [_outlineView selectedItem];
    NSString *titleSuggestion = nil;
    if (node && [[node representedObject] isKindOfClass:[CustomQuery class]]) {
        CustomQuery *existingQuery = [node representedObject];
        titleSuggestion = existingQuery.title;
    }
    
    SaveSearchController *save = [SaveSearchController new];
    save.title = titleSuggestion;
    [save beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            NSString *title = save.title;
            BOOL exists = [[[DataStore activeStore] myQueries] containsObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"title = %@ AND authorIdentifier = %@", title, [[User me] identifier]]];
            if (exists) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = NSLocalizedString(@"A query with that title already exists.", nil);
                alert.informativeText = NSLocalizedString(@"Are you sure you want to replace it?", nil);
                [alert addButtonWithTitle:NSLocalizedString(@"Replace", nil)];
                [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
                if ([alert runModal] != NSAlertFirstButtonReturn) {
                    return;
                }
            }
            
            CustomQuery *query = [CustomQuery new];
            query.title = title;
            query.predicate = [_predicateEditor predicate];
            
            _nextNodeToSelect = query.identifier;
            [[DataStore activeStore] saveQuery:query completion:^(NSArray *myQueries) { }];
        }
    }];
}

- (void)searchEditorViewControllerSavePredicate:(SearchEditorViewController *)vc {
    OverviewNode *node = [_outlineView selectedItem];
    if (node && [[node representedObject] isKindOfClass:[CustomQuery class]]) {
        CustomQuery *existingQuery = [node representedObject];
        if (![existingQuery.authorIdentifier isEqualToString:[[User me] identifier]]) {
            return;
        }
        
        existingQuery.predicate = [_predicateEditor predicate];
        [[DataStore activeStore] saveQuery:existingQuery completion:^(NSArray *myQueries) { }];
    }
}
#endif

#pragma mark - FilterBarViewControllerDelegate

- (void)filterBar:(FilterBarViewController *)vc didUpdatePredicate:(NSPredicate *)newPredicate {
    [self updatePredicate];
}

#pragma mark - Query Actions

#if !INCOMPLETE
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
            [[DataStore activeStore] hideQuery:query completion:^(NSArray *myQueries) { }];
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
#endif

- (void)textDidBeginEditing:(NSNotification *)notification {

}

- (void)textDidEndEditing:(NSNotification *)notification {
#if !INCOMPLETE
    id sender = [notification object];
    OverviewNode *node = [sender representedObject];
    CustomQuery *query = [node representedObject];
    [sender setStringValue:query.title];
#endif
}

#if !INCOMPLETE
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
    
    if (!found) {
        self.nextNodeToSelect = query.identifier;
        [[DataStore activeStore] watchQuery:query completion:^(NSArray *myQueries) { }];
    }
}

- (void)bookmarkQuery:(id)sender {
    CustomQuery *query = [[sender menu] extras_representedObject];
    
    if (!query) return;
    

    self.nextNodeToSelect = query.identifier;
    [[DataStore activeStore] bookmarkQuery:query completion:^(NSArray *myQueries) { }];
}

- (void)removeRecentQuery:(id)sender {
    CustomQuery *query = [[sender menu] extras_representedObject];
    
    if (!query) return;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to remove the recent query “%@”?", nil), query.title];
    alert.informativeText = NSLocalizedString(@"This will remove the query from your recents list. It will not affect the query's owner. This action cannot be undone.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Remove", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [[DataStore activeStore] unwatchQuery:query completion:^(NSArray *myQueries) { }];
        }
    }];
}

- (void)removeBookmarkedQuery:(id)sender {
    CustomQuery *query = [[sender menu] extras_representedObject];
    
    if (!query) return;
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to remove the bookmarked query “%@”?", nil), query.title];
    alert.informativeText = NSLocalizedString(@"This will remove the query from your bookmarks. It will not affect the query's owner. This action cannot be undone.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Remove", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [[DataStore activeStore] unwatchQuery:query completion:^(NSArray *myQueries) { }];
        }
    }];
}
#endif

- (IBAction)copyURL:(id)sender {
#if !INCOMPLETE
    id selectedItem = [_outlineView selectedItem];
    if ([[selectedItem representedObject] isKindOfClass:[CustomQuery class]]) {
        CustomQuery *query = [selectedItem representedObject];
        NSURL *URL = [query URL];
        NSString *title = [query URLAndTitle];
        
        NSPasteboard *pb = [NSPasteboard generalPasteboard];
        [pb clearContents];
        [pb writeURL:URL string:title];
    }
#endif
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(showChart:)) {
        return _modeItem.chartEnabled;
    } else if (menuItem.action == @selector(showChartOptions:)) {
        return _modeItem.mode == ResultsViewModeChart;
    } else if (menuItem.action == @selector(copyURL:)) {
#if !INCOMPLETE
        id selectedItem = [_outlineView selectedItem];
        if ([[selectedItem representedObject] isKindOfClass:[CustomQuery class]]) {
            return YES;
        }
#endif
        return NO;
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
#if !INCOMPLETE
    [_outlineView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    
    _predicateItem.on = YES;
    [_predicateEditor reset];
    
    [self updateSearchSplit];
    [self updatePredicate];
#endif
}

- (IBAction)addNewMilestone:(id)sender {
#if !INCOMPLETE
    AppDelegate *delegate = [NSApp delegate];
    [delegate showAdminWindow:sender];
#endif
}

#pragma mark -

- (NSArray <id<ProblemSnapshot>> *)selectedProblemSnapshots {
    if (_modeItem.mode == ResultsViewModeList) {
        return [_searchResults selectedProblemSnapshots];
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

@implementation SearchSplit

- (CGFloat)dividerThickness {
    return 0.0;
}

- (void)resetCursorRects {
    
}

@end

@implementation OverviewCellView

@end

@implementation OverviewWindow

- (void)toggleToolbarShown:(id)sender {
    // Default NSWindow implementation toggles all toolbars with the same identifier.
    // We don't want this.
    // See ship://Problems/230 <Hide toolbar hides all the toolbars>
    
    self.toolbar.visible = !self.toolbar.visible;
}

@end
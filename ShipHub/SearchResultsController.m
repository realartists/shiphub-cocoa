//
//  SearchResultsController.m
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SearchResultsControllerPrivate.h"
#import "Extras.h"
#import "IssueTableController.h"
#import "IssueTableControllerPrivate.h"
#import "DataStore.h"
#import "Issue.h"
#import "EmptyUpNextViewController.h"
#import "UpNextHelper.h"

@interface IssueTableController (Internal)
@property (nonatomic, assign) BOOL loading;
@end

@interface SearchResultsController () {
    NSInteger _searchGeneration;
}

@property IssueTableController *table;
@property (nonatomic, assign) BOOL searching;
@property NSTimer *titleTimer;
@property EmptyUpNextViewController *emptyVC;

@end

@implementation SearchResultsController

@dynamic delegate;

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    _table = [[IssueTableController alloc] init];
    _table.delegate = self;
    [self updateTablePrefs];
    NSView *tableView = _table.view;
    self.view = [[NSView alloc] initWithFrame:tableView.frame];
    [self.view setContentView:tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSourceUpdated:) name:DataStoreDidUpdateProblemsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSourceUpdated:) name:DataStoreDidUpdateMetadataNotification object:nil];
}

- (BOOL)isBordered {
    [self view];
    return self.table.table.enclosingScrollView.borderType != NSNoBorder;
}

- (void)setBordered:(BOOL)bordered {
    [self view];
    self.table.table.enclosingScrollView.borderType = NSLineBorder;
}

- (void)dataSourceUpdated:(NSNotification *)note {
    [self refresh:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    return [[DataStore activeStore] isValid];
}

- (IBAction)refresh:(id)sender {
    [self refreshWithPredicate:self.predicate];
}

- (void)refreshWithPredicate:(NSPredicate *)predicate {
    _searchGeneration++;
    
    if (!predicate) {
        self.searching = NO;
        _table.tableItems = nil;
        return;
    }
    
    NSInteger generation = _searchGeneration;
    self.searching = YES;
    
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"number" ascending:YES]];
    NSDictionary *options = nil;
    
    if (self.upNextMode) {
        options = @{ IssueOptionIncludeUpNextPriority : @YES };
    }
    
    [[DataStore activeStore] issuesMatchingPredicate:predicate sortDescriptors:sortDescriptors options:options completion:^(NSArray<Issue *> *issues, NSError *error) {
        if (generation != _searchGeneration) return;
        
        if (issues) {
            issues = [self willUpdateItems:issues];
            _table.tableItems = issues;
            [self didUpdateItems];
        } else {
            [self presentError:error modalForWindow:self.view.window delegate:nil didPresentSelector:nil contextInfo:NULL];
        }
        self.searching = NO;
    }];
}

- (NSArray *)willUpdateItems:(NSArray *)proposedItems {
    return proposedItems;
}

- (void)didUpdateItems {
    
}

- (IBAction)revertDocumentToSaved:(id)sender {
    [self refresh:sender];
}

- (void)setPredicate:(NSPredicate *)predicate {
    if (![self.predicate isEqual:predicate]) {
        DebugLog(@"%@ refreshing with predicate %@ (prev:%@)", self, predicate, self.predicate);
        [super setPredicate:predicate];
        [self refresh:nil];
    }
}

- (void)titleTimerFired:(NSTimer *)timer {
    self.titleTimer = nil;
    self.title = nil;
}

- (void)setSearching:(BOOL)searching {
    _searching = searching;
    self.inProgress = searching;
    
    [self updateTitle];
}

- (void)updateTitle {
    if (_searching) {
        if (!self.titleTimer) {
            self.titleTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(titleTimerFired:) userInfo:nil repeats:NO];
        }
    } else {
        [self.titleTimer invalidate];
        self.titleTimer = nil;
        NSUInteger count = _table.tableItems.count;
        if (count != 1) {
            self.title = [NSString localizedStringWithFormat:NSLocalizedString(@"%td items", nil), _table.tableItems.count];
        } else {
            self.title = NSLocalizedString(@"1 item", nil);
        }
    }
}

- (NSArray<Issue *> *)selectedProblemSnapshots {
    return [_table selectedProblemSnapshots];
}

- (void)setUpNextMode:(BOOL)upNextMode {
    [super setUpNextMode:upNextMode];
    [self updateTablePrefs];
}

- (void)updateTablePrefs {
    _table.autosaveName = [self autosaveName];
    if (self.upNextMode) {
        _table.upNextMode = YES;
        if (!_emptyVC) {
            _emptyVC = [EmptyUpNextViewController new];
        }
        _table.emptyPlaceholderViewController = _emptyVC;
    } else {
        _table.upNextMode = NO;
        _table.emptyPlaceholderViewController = nil;
    }
}

- (NSString *)autosaveName {
    return @"SearchResults";
}

- (BOOL)issueTableController:(IssueTableController *)controller shouldAcceptDrop:(NSArray *)issueIdentifiers {
    return self.upNextMode;
}

- (void)issueTableController:(IssueTableController *)controller didAcceptDrop:(NSArray *)issueIdentifiers aboveItemAtIndex:(NSInteger)idx {
    Issue *context = nil;
    if (idx < _table.tableItems.count) {
        context = _table.tableItems[idx];
    }
    [[UpNextHelper sharedHelper] insertIntoUpNext:issueIdentifiers aboveIssueIdentifier:context.fullIdentifier window:controller.view.window completion:nil];
}

- (void)issueTableController:(IssueTableController *)controller didReorderItems:(NSArray<Issue *> *)items aboveItemAtIndex:(NSInteger)idx {
    NSArray *issueIdentifiers = [items arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }];
    
    [self issueTableController:controller didAcceptDrop:issueIdentifiers aboveItemAtIndex:idx];
}

- (BOOL)issueTableController:(IssueTableController *)controller deleteItems:(NSArray<Issue *> *)items {
    if (!self.upNextMode) {
        return NO;
    }
    
    [[UpNextHelper sharedHelper] removeFromUpNext:[items arrayByMappingObjects:^id(id obj) {
        return [obj fullIdentifier];
    }] window:controller.view.window completion:nil];
    
    return YES;
}

- (void)issueTableController:(IssueTableController *)controller didChangeSelection:(NSArray<Issue *> *)selectedIssues userInitiated:(BOOL)userInitiated
{
    [self.delegate searchResultsControllerDidChangeSelection:self];
}

- (void)takeFocus {
    [self.view.window makeFirstResponder:_table.view];
}

- (id)supplementalTargetForAction:(SEL)action sender:(id)sender {
    id target = [super supplementalTargetForAction:action sender:sender];
    
    if (target != nil) {
        return target;
    }
    
    NSViewController *right = [self table];
    target = [NSApp targetForAction:action to:right from:sender];
    
    if (![target respondsToSelector:action]) {
        target = [target supplementalTargetForAction:action sender:sender];
    }
    
    if ([target respondsToSelector:action]) {
        return target;
    }
    
    return nil;
}


@end

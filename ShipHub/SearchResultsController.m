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
#import "DataStore.h"
#import "Issue.h"

@interface IssueTableController (Internal)
@property (nonatomic, assign) BOOL loading;
@end

@interface SearchResultsController () {
    NSInteger _searchGeneration;
}

@property IssueTableController *table;
@property (nonatomic, assign) BOOL searching;
@property NSTimer *titleTimer;

@end

@implementation SearchResultsController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    _table = [[IssueTableController alloc] init];
    _table.autosaveName = @"SearchResults";
    NSView *tableView = _table.view;
    self.view = [[NSView alloc] initWithFrame:tableView.frame];
    [self.view setContentView:tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dataSourceUpdated:) name:DataStoreDidUpdateProblemsNotification object:nil];
}

- (void)dataSourceUpdated:(NSNotification *)note {
    [self refresh:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    return [[DataStore activeStore] isValid];
}

- (IBAction)refresh:(id)sender {
    _searchGeneration++;
    
    if (!self.predicate) {
        self.searching = NO;
        _table.tableItems = nil;
        return;
    }
    
    // FIXME: Hook up
    NSInteger generation = _searchGeneration;
    self.searching = YES;
    
    [[DataStore activeStore] issuesMatchingPredicate:self.predicate completion:^(NSArray<Issue *> *issues, NSError *error) {
        if (generation != _searchGeneration) return;
        
        if (issues) {
            _table.tableItems = [issues arrayByMappingObjects:^id(id obj) {
                SearchTableItem *item = [SearchTableItem new];
                item.issue = obj;
                return item;
            }];
        } else {
            [self presentError:error modalForWindow:self.view.window delegate:nil didPresentSelector:nil contextInfo:NULL];
        }
        self.searching = NO;
    }];
}

- (IBAction)revertDocumentToSaved:(id)sender {
    [self refresh:sender];
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
        NSUInteger count = _table.tableItems.count;
        if (count != 1) {
            self.title = [NSString localizedStringWithFormat:NSLocalizedString(@"%td items", nil), _table.tableItems.count];
        } else {
            self.title = NSLocalizedString(@"1 item", nil);
        }
    }
}

- (NSArray <id<ProblemSnapshot>> *)selectedProblemSnapshots {
    return [_table selectedProblemSnapshots];
}

@end

@implementation SearchTableItem

- (id)issueFullIdentifier {
    return self.issue.fullIdentifier;
}

- (id<NSCopying>)identifier {
    return [self issueFullIdentifier];
}

@end

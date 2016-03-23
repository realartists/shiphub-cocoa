//
//  SearchResultsController.m
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SearchResultsController.h"
#import "Extras.h"
#import "ProblemTableController.h"
#import "DataStore.h"

@interface SearchTableItem : NSObject <ProblemTableItem>

@property (nonatomic, strong) id<ProblemSnapshot> problemSnapshot;

@end

@interface ProblemTableController (Internal)
@property (nonatomic, assign) BOOL loading;
@end

@interface SearchResultsController () {
    NSInteger _searchGeneration;
}

@property ProblemTableController *table;
@property (nonatomic, assign) BOOL searching;
@property NSTimer *titleTimer;

@end

@implementation SearchResultsController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    _table = [[ProblemTableController alloc] init];
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
#if !INCOMPLETE
    NSInteger generation = _searchGeneration;
    self.searching = YES;
    [[DataStore activeStore] findProblemsMatchingPredicate:self.predicate completion:^(NSArray *snapshots, NSError *error) {
        if (generation != _searchGeneration) return;
        
        if (snapshots) {
            _table.tableItems = [snapshots arrayByMappingObjects:^id(id obj) {
                SearchTableItem *item = [SearchTableItem new];
                item.problemSnapshot = obj;
                return item;
            }];
        } else {
            [self presentError:error modalForWindow:self.view.window delegate:nil didPresentSelector:nil contextInfo:NULL];
        }
        self.searching = NO;
    }];
#endif
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

- (NSNumber *)problemIdentifier {
    // FIXME: Hook up
#if !INCOMPLETE
    return self.problemSnapshot.identifier;
#else
    return @0;
#endif
}

- (id<NSCopying>)identifier {
    // FIXME: Hook up
#if !INCOMPLETE
    return self.problemSnapshot.identifier;
#else
    return @0;
#endif
}

@end

//
//  FilterBarViewController.m
//  ShipHub
//
//  Created by James Howard on 6/17/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "FilterBarViewController.h"

#import "Extras.h"
#import "FilterButton.h"
#import "LabelsFilterViewController.h"
#import "Account.h"
#import "MetadataStore.h"
#import "DataStore.h"
#import "NSPredicate+Extras.h"

@interface FilterBarViewController () <LabelsFilterViewControllerDelegate>

@property (readwrite) NSPredicate *predicate;

@property FilterButton *repo;
@property FilterButton *assignee;
@property FilterButton *author;
@property FilterButton *state;
@property FilterButton *label;
@property FilterButton *milestone;
@property FilterButton *pullRequest;

@property LabelsFilterViewController *labelsFilter;

@property NSMutableArray *filters;

@property CGFloat lastViewWidth;

@property (weak) NSWindow *window;

@end

#define LINE_HEIGHT 22.0

@implementation FilterBarViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 480.0, LINE_HEIGHT)];
    self.view = container;
    self.fullScreenMinHeight = container.frame.size.height;
    
    _filters = [NSMutableArray new];
    
    _repo = [self popUpButton];
    [self addFilter:_repo];
    [self buildRepoMenu];
    
    _assignee = [self popUpButton];
    [self addFilter:_assignee];
    [self buildAssigneeMenu];
    
    _author = [self popUpButton];
    [self addFilter:_author];
    [self buildAuthorMenu];
    
    _state = [self popUpButton];
    [self addFilter:_state];
    [self buildStateMenu];
    
    _label = [self popUpButton];
    [self addFilter:_label];
    [self updateLabels];
    
    _milestone = [self popUpButton];
    [self addFilter:_milestone];
    [self buildMilestoneMenu];
    
    _pullRequest = [self popUpButton];
    [self addFilter:_pullRequest];
    [self buildPullRequestMenu];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataChanged:) name:DataStoreDidUpdateMetadataNotification object:nil];
}

- (FilterButton *)popUpButton {
    FilterButton *button = [[FilterButton alloc] initWithFrame:CGRectMake(5.0, 1.0, 100.0, 16.0) pullsDown:YES];
    button.font = [NSFont systemFontOfSize:11.0];
    [button sizeToFit];
    return button;
}


- (void)addFilter:(FilterButton *)filter {
    [_filters addObject:filter];
    [self.view addSubview:filter];
}

- (void)viewWillLayout {
    [super viewWillLayout];
    [self layoutButtons];
}

- (void)rebuildMenus {
    [self buildAssigneeMenu];
    [self buildAuthorMenu];
    [self buildRepoMenu];
    [self updateLabels];
    [self buildMilestoneMenu];
    [self buildPullRequestMenu];
}

- (void)metadataChanged:(NSNotification *)note {
    [self rebuildMenus];
}

- (MetadataStore *)metadata {
    return [[DataStore activeStore] metadataStore];
}

#pragma mark - Predicate Examination

// returns nil if no comparison of keyPath is present.
// returns [NSNull null] if the comparison is present, but the compared to value is nil
// otherwise returns the compared to value.
- (id)valueInPredicate:(NSPredicate *)predicate forKeyPath:(NSString *)keyPath {
    NSArray *predicates = [predicate predicatesMatchingPredicate:[NSPredicate predicateMatchingComparisonPredicateWithKeyPath:keyPath]];
    NSComparisonPredicate *c0 = [predicates firstObject];
    if (!c0) return nil;
    
    NSExpression *lhs = c0.leftExpression;
    NSExpression *rhs = c0.rightExpression;
    
    NSExpression *e;
    if (lhs.expressionType == NSKeyPathExpressionType && [lhs.keyPath isEqualToString:keyPath]) {
        e = rhs;
    } else {
        e = lhs;
    }
    
    id v = [e expressionValueWithObject:nil context:nil];
    
    if (!v) v = [NSNull null];
    
    return v;
}

- (id)userLoginInPredicate:(NSPredicate *)predicate field:(NSString *)field {
    id login = [self valueInPredicate:predicate forKeyPath:[NSString stringWithFormat:@"%@.login", field]];
    if (login) {
        return login;
    } else {
        id identifier = [self valueInPredicate:predicate forKeyPath:[NSString stringWithFormat:@"%@.identifier", field]];
        if (identifier) {
            if (identifier == [NSNull null]) return identifier;
            return [[[self metadata] accountWithIdentifier:identifier] login];
        } else {
            id user = [self valueInPredicate:predicate forKeyPath:field];
            if (user == [NSNull null]) return user;
        }
    }
    return nil;
}

- (id)assigneeLoginInPredicate:(NSPredicate *)predicate {
    __block BOOL unassigned = NO;
    __block id login = nil;
    __block id identifier = nil;
    
    NSArray *predicates = [predicate predicatesMatchingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if ([evaluatedObject isKindOfClass:[NSComparisonPredicate class]])
        {
            NSComparisonPredicate *c0 = evaluatedObject;
            NSExpression *lhs = c0.leftExpression;
            
            if (lhs.expressionType == NSFunctionExpressionType && [lhs.function isEqualToString:@"count:"])
            {
                NSExpression *kp = [lhs.arguments firstObject];
                if (kp.expressionType == NSKeyPathExpressionType
                    && [kp.keyPath isEqualToString:@"assignees"])
                {
                    NSExpression *v = c0.rightExpression;
                    
                    if (v.expressionType == NSConstantValueExpressionType
                        && [v.constantValue isEqual:@0])
                    {
                        unassigned = YES;
                        return YES;
                    }
                    
                    return YES;
                }
            } else if (c0.comparisonPredicateModifier == NSAnyPredicateModifier
                       && lhs.expressionType == NSKeyPathExpressionType
                       && ([lhs.keyPath isEqualToString:@"assignees.login"]
                           || [lhs.keyPath isEqualToString:@"assignees.identifier"]))
            {
                NSExpression *rhs = c0.rightExpression;
                if ([lhs.keyPath isEqualToString:@"assignees.login"]) {
                    login = [rhs expressionValueWithObject:nil context:NULL];
                } else {
                    identifier = [rhs expressionValueWithObject:nil context:NULL];
                }
                return YES;
            }
        }
        return NO;
    }]];
    
    if ([predicates count] > 0) {
        if (unassigned) {
            return [NSNull null];
        } else if (login) {
            return login;
        } else if (identifier) {
            if (identifier == [NSNull null]) return identifier;
            return [[[self metadata] accountWithIdentifier:identifier] login];
        }
    }
    
    return nil;
}

- (id)authorLoginInPredicate:(NSPredicate *)predicate {
    return [self userLoginInPredicate:predicate field:@"originator"];
}

- (Repo *)repoInPredicate:(NSPredicate *)predicate {
    id repoIdentifier = [self valueInPredicate:predicate forKeyPath:@"repository.identifier"];
    if (repoIdentifier) {
        return [[self metadata] repoWithIdentifier:repoIdentifier];
    }
    id repoFullName = [self valueInPredicate:predicate forKeyPath:@"repository.fullName"];
    if (repoFullName) {
        return [[[[self metadata] activeRepos] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"fullName == %@", repoFullName] limit:1] firstObject];
    }
    return nil;
}

- (id)closedInPredicate:(NSPredicate *)predicate {
    id val = [self valueInPredicate:predicate forKeyPath:@"state"];
    if (val && [val isEqualToString:@"open"]) return @NO;
    else if (val && [val isEqualToString:@"closed"]) return @YES;
    else return [self valueInPredicate:predicate forKeyPath:@"closed"];
}

- (BOOL)hasLabelsInPredicate:(NSPredicate *)predicate {
    return [self valueInPredicate:predicate forKeyPath:@"labels.name"] != nil;
}

- (id)milestoneTitleInPredicate:(NSPredicate *)predicate {
    id identifier = [self valueInPredicate:predicate forKeyPath:@"milestone.identifier"];
    if (identifier) {
        return [[[self metadata] milestoneWithIdentifier:identifier] title];
    }
    id title = [self valueInPredicate:predicate forKeyPath:@"milestone.title"];
    if (title) return title;
    id ms = [self valueInPredicate:predicate forKeyPath:@"milestone"];
    if (ms == [NSNull null]) return ms;
    else return [ms title];
}

- (NSNumber *)pullRequestInPredicate:(NSPredicate *)predicate {
    id val = [self valueInPredicate:predicate forKeyPath:@"pullRequest"];
    return val;
}

#pragma mark - Menu Builders

- (void)buildUserMenu:(FilterButton *)button action:(SEL)action notSet:(NSString *)notSet {
    MetadataStore *meta = [self metadata];
    Repo *repo = [self repoInPredicate:_basePredicate];
    if (!repo) {
        repo = [self repoInPredicate:_predicate];
    }
    NSArray *assignees = nil;
    if (repo) {
        assignees = [meta assigneesForRepo:repo];
    } else {
        // want the union of assignees in all repos
        NSMutableSet *s = [NSMutableSet new];
        for (Repo *r in [meta activeRepos]) {
            [s addObjectsFromArray:[meta assigneesForRepo:r]];
        }
        assignees = [s allObjects];
    }
    
    assignees = [[assignees arrayByMappingObjects:^id(id obj) {
        return [obj login];
    }] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    
    NSMenu *menu = [NSMenu new];
    
    NSMenuItem *m;
    
    m = [menu addItemWithTitle:NSLocalizedString(@"Don't Filter", nil) action:action keyEquivalent:@""];
    m.representedObject = nil;
    m.target = self;
    
    if (notSet) {
        m = [menu addItemWithTitle:notSet action:action keyEquivalent:@""];
        m.representedObject = [NSNull null];
        m.target = self;
    }
    
    for (NSString *login in assignees) {
        m = [menu addItemWithTitle:login action:action keyEquivalent:@""];
        m.representedObject = login;
        m.target = self;
    }
    
    button.menu = menu;
}

- (void)buildAssigneeMenu {
    [self buildUserMenu:_assignee action:@selector(pickAssignee:) notSet:NSLocalizedString(@"Unassigned", nil)];
    [self updateAssigneeMenuStateFromPredicate];
}

- (void)buildAuthorMenu {
    [self buildUserMenu:_author action:@selector(pickAuthor:) notSet:nil];
    [self updateAuthorMenuStateFromPredicate];
}

- (void)buildRepoMenu {
    MetadataStore *meta = [self metadata];
    
    NSMenu *menu = [NSMenu new];
    
    NSMenuItem *m = [menu addItemWithTitle:NSLocalizedString(@"All Repos", nil) action:@selector(pickRepo:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = nil;
    
    BOOL multipleOwners = [[meta repoOwners] count] > 1;
    
    if (multipleOwners) {
        for (Account *repoOwner in [meta repoOwners]) {
            NSMenuItem *accountItem = [menu addItemWithTitle:repoOwner.login action:nil keyEquivalent:@""];
            NSMenu *submenu = [NSMenu new];
            accountItem.submenu = submenu;
            
            for (Repo *repo in [meta reposForOwner:repoOwner]) {
                m = [submenu addItemWithTitle:repo.name action:@selector(pickRepo:) keyEquivalent:@""];
                m.target = self;
                m.representedObject = repo;
            }
        }
    } else {
        for (Repo *repo in [meta activeRepos]) {
            m = [menu addItemWithTitle:repo.name action:@selector(pickRepo:) keyEquivalent:@""];
            m.target = self;
            m.representedObject = repo;
        }
    }
    
    _repo.menu = menu;
    
    [self updateRepoMenuStateFromPredicate];
}

- (void)buildStateMenu {
    NSMenuItem *m;
    NSMenu *menu = [NSMenu new];
    
    m = [menu addItemWithTitle:NSLocalizedString(@"Don't Filter", nil) action:@selector(pickState:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = nil;
    
    m = [menu addItemWithTitle:NSLocalizedString(@"Open", nil) action:@selector(pickState:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = @NO; // closed = NO
    
    m = [menu addItemWithTitle:NSLocalizedString(@"Closed", nil) action:@selector(pickState:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = @YES;
    
    _state.menu = menu;
    
    [self updateStateMenuStateFromPredicate];
}

- (void)updateLabels {
    MetadataStore *meta = [self metadata];
    Repo *repo = [self repoInPredicate:_basePredicate];
    if (!repo) {
        repo = [self repoInPredicate:_predicate];
    }
    
    BOOL hasLabelsInBase = [self hasLabelsInPredicate:_basePredicate];
    
    NSMutableSet *seenLabelNames = [NSMutableSet new];
    NSMutableArray *uniqueLabels = [NSMutableArray new];
    
    void (^visitLabel)(Label *) = ^(Label *label) {
        if (![seenLabelNames containsObject:label.name]) {
            [seenLabelNames addObject:label.name];
            [uniqueLabels addObject:label];
        }
    };
    
    if (repo) {
        for (Label *label in [meta labelsForRepo:repo]) {
            visitLabel(label);
        }
    } else {
        for (Repo *r in [meta activeRepos]) {
            for (Label *label in [meta labelsForRepo:r]) {
                visitLabel(label);
            }
        }
    }
    
    if (!_labelsFilter) {
        _labelsFilter = [LabelsFilterViewController new];
        _labelsFilter.delegate = self;
        _label.popoverViewController = _labelsFilter;
    }
    
    [_labelsFilter setLabels:uniqueLabels predicate:_predicate];
    
    _labelsFilter.showPredicateCombinedWarning = hasLabelsInBase;
    
    NSString *filterTitle = _labelsFilter.title;
    BOOL labelsEnabled = filterTitle.length > 0;
    NSString *labelTitle;
    if (filterTitle.length > 0) {
        labelTitle = [NSString stringWithFormat:NSLocalizedString(@"Labels - %@", nil), filterTitle];
    } else {
        labelTitle = NSLocalizedString(@"Labels", nil);
    }
    
    if (labelsEnabled != _label.enabled || ![_label.title isEqualToString:labelTitle]) {
        _label.filterEnabled = labelsEnabled;
        _label.title = labelTitle;
        [self needsButtonLayout];
    }
}

- (void)buildMilestoneMenu {
    MetadataStore *meta = [self metadata];
    Repo *repo = [self repoInPredicate:_basePredicate];
    
    NSArray *milestones = nil;
    
    if (repo) {
        milestones = [[meta activeMilestonesForRepo:repo] arrayByMappingObjects:^id(id obj) {
            return [obj title];
        }];
    } else {
        milestones = [meta mergedMilestoneNames];
    }
    
    NSMenu *menu = [NSMenu new];
    NSMenuItem *m;
    
    m = [menu addItemWithTitle:NSLocalizedString(@"Don't Filter", nil) action:@selector(pickMilestone:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = nil;
    
    m = [menu addItemWithTitle:NSLocalizedString(@"No Milestone", nil) action:@selector(pickMilestone:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = [NSNull null];
    
    for (NSString *title in milestones) {
        m = [menu addItemWithTitle:title action:@selector(pickMilestone:) keyEquivalent:@""];
        m.target = self;
        m.representedObject = title;
    }
    
    _milestone.menu = menu;
    
    [self updateMilestoneMenuStateFromPredicate];
}

- (void)buildPullRequestMenu {
    NSMenu *menu = [NSMenu new];
    NSMenuItem *m;
    
    m = [menu addItemWithTitle:NSLocalizedString(@"Issues & PRs", nil) action:@selector(pickPullRequest:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = nil;
    
    m = [menu addItemWithTitle:NSLocalizedString(@"Issues Only", nil) action:@selector(pickPullRequest:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = @NO;
    
    m = [menu addItemWithTitle:NSLocalizedString(@"Pull Requests Only", nil) action:@selector(pickPullRequest:) keyEquivalent:@""];
    m.target = self;
    m.representedObject = @YES;
    
    _pullRequest.menu = menu;
    
    [self updatePullRequestMenuStateFromPredicate];
}

#pragma mark - Menu Updaters

static BOOL representedObjectEquals(id repr, id val) {
    if (repr == nil && val == nil) return YES;
    if (repr == nil && val != nil) return NO;
    if (repr != nil && val == nil) return NO;
    if ([repr isKindOfClass:[NSNumber class]] || [repr isKindOfClass:[NSString class]] || [repr isKindOfClass:[NSNull class]]) {
        return [repr isEqual:val];
    } else {
        return [[repr identifier] isEqual:[val identifier]];
    }
}

- (void)updateAssigneeMenuStateFromPredicate {
    id login = [self assigneeLoginInPredicate:_predicate];
    
    for (NSMenuItem *m in _assignee.menu.itemArray) {
        m.state = representedObjectEquals(m.representedObject, login) ? NSOnState : NSOffState;
    }
    
    BOOL filtered = YES;
    if (login == nil) {
        filtered = NO;
        _assignee.title = NSLocalizedString(@"Assignee", nil);
    } else if (login == [NSNull null]) {
        _assignee.title = NSLocalizedString(@"Assignee - Unassigned", nil);
    } else {
        _assignee.title = [NSString stringWithFormat:NSLocalizedString(@"Assignee - %@", nil), login];
    }
    
    _assignee.filterEnabled = filtered;
    [self needsButtonLayout];
}

- (void)updateAuthorMenuStateFromPredicate {
    id login = [self authorLoginInPredicate:_predicate];
    
    for (NSMenuItem *m in _author.menu.itemArray) {
        m.state = representedObjectEquals(m.representedObject, login) ? NSOnState : NSOffState;
    }
    
    BOOL filtered = YES;
    if (login == nil) {
        filtered = NO;
        _author.title = NSLocalizedString(@"Author", nil);
    } else if (login == [NSNull null]) {
        NSAssert(NO, @"Should never have a predicate with a NULL author");
    } else {
        _author.title = [NSString stringWithFormat:NSLocalizedString(@"Author - %@", nil), login];
    }
    
    _author.filterEnabled = filtered;
    [self needsButtonLayout];
}

- (void)updateRepoMenuStateFromPredicate {
    id repo = [self repoInPredicate:_predicate];
    
    [_repo.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        if (m.target == self) {
            m.state = representedObjectEquals(m.representedObject, repo) ? NSOnState : NSOffState;
        }
    }];
    
    BOOL filtered = repo != nil;
    if (filtered) {
        _repo.title = [NSString stringWithFormat:NSLocalizedString(@"Repo - %@", nil), [repo name]];
    } else {
        _repo.title = NSLocalizedString(@"Repo", nil);
    }
    
    _repo.filterEnabled = filtered;
    [self needsButtonLayout];
}

- (void)updateStateMenuStateFromPredicate {
    id closed = [self closedInPredicate:_predicate];
    
    [_state.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        m.state = representedObjectEquals(m.representedObject, closed) ? NSOnState: NSOffState;
    }];
    
    if (closed == nil) {
        _state.title = NSLocalizedString(@"State", nil);
    } else if ([closed boolValue]) {
        _state.title = NSLocalizedString(@"State - Closed", nil);
    } else {
        _state.title = NSLocalizedString(@"State - Open", nil);
    }
    
    _state.filterEnabled = closed != nil;
    [self needsButtonLayout];
}

- (void)updateMilestoneMenuStateFromPredicate {
    id milestone = [self milestoneTitleInPredicate:_predicate];
    
    [_milestone.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        m.state = m.action == @selector(pickMilestone:) && representedObjectEquals(m.representedObject, milestone) ? NSOnState : NSOffState;
    }];
    
    if (!milestone) {
        _milestone.filterEnabled = NO;
        _milestone.title = NSLocalizedString(@"Milestone", nil);
    } else if (milestone == [NSNull null]) {
        _milestone.filterEnabled = YES;
        _milestone.title = NSLocalizedString(@"No Milestone", nil);
    } else {
        _milestone.filterEnabled = YES;
        _milestone.title = [NSString stringWithFormat:NSLocalizedString(@"Milestone - %@", nil), milestone];
    }
    
    [self needsButtonLayout];
}

- (void)updatePullRequestMenuStateFromPredicate {
    NSNumber *val = [self pullRequestInPredicate:_predicate];
    
    __block NSString *title = @"";
    [_pullRequest.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        if (representedObjectEquals(m.representedObject, val)) {
            title = m.title;
            m.state = NSOnState;
        } else {
            m.state = NSOffState;
        }
    }];
    
    _pullRequest.filterEnabled = val != nil;
    _pullRequest.title = title;
    
    [self needsButtonLayout];
}

#pragma mark - Menu Actions

- (void)pickAssignee:(id)sender {
    for (NSMenuItem *m in _assignee.menu.itemArray) {
        m.state = m == sender ? NSOnState : NSOffState;
    }
    
    [self updatePredicateFromFilterButtons];
    [self updateAssigneeMenuStateFromPredicate];
}

- (void)pickAuthor:(id)sender {
    for (NSMenuItem *m in _author.menu.itemArray) {
        m.state = m == sender ? NSOnState : NSOffState;
    }
    
    [self updatePredicateFromFilterButtons];
    [self updateAuthorMenuStateFromPredicate];
}

- (void)pickRepo:(id)sender {
    [_repo.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        if (m.target == self) {
            m.state = m == sender ? NSOnState : NSOffState;
        }
    }];
    
    [_label.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        if (m.target == self) {
            m.state = m.representedObject == nil ? NSOnState : NSOffState;
        }
    }];
    
    [self updatePredicateFromFilterButtons];
    [self updateRepoMenuStateFromPredicate];
    
    [self updateLabels];
    [self buildMilestoneMenu];
    [self buildAssigneeMenu];
    [self buildAuthorMenu];
}

- (void)pickState:(id)sender {
    [_state.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        m.state = m == sender ? NSOnState : NSOffState;
    }];
    
    [self updatePredicateFromFilterButtons];
    [self updateStateMenuStateFromPredicate];
}

- (void)labelsFilterViewController:(LabelsFilterViewController *)controller didUpdateLabelsPredicate:(NSPredicate *)labelsPredicate shouldClosePopover:(BOOL)closePopover {
    [self updatePredicateFromFilterButtons];
    [self updateLabels];
    if (closePopover) {
        [_label closePopover];
    }
}

- (void)pickMilestone:(id)sender {
    [_milestone.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        m.state = m == sender ? NSOnState : NSOffState;
    }];
    
    [self updatePredicateFromFilterButtons];
    [self updateMilestoneMenuStateFromPredicate];
}

- (void)pickPullRequest:(id)sender {
    [_pullRequest.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        m.state = m == sender ? NSOnState : NSOffState;
    }];
    
    [self updatePredicateFromFilterButtons];
    [self updatePullRequestMenuStateFromPredicate];
}

#pragma mark - FilterButton Utils

- (id)selectedObjectInFilter:(FilterButton *)f {
    __block id item = nil;
    [f.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        if (m.target == self && m.state == NSOnState) {
            item = m.representedObject;
            *stop = YES;
        }
    }];
    
    return item;
}

- (NSArray *)selectedObjectsInFilter:(FilterButton *)f {
    NSMutableArray *a = [NSMutableArray new];
    
    [f.menu walkMenuItems:^(NSMenuItem *m, BOOL *stop) {
        if (m.target == self && m.state == NSOnState) {
            [a addObject:m.representedObject];
        }
    }];
    
    return a;
}

#pragma mark - buttons => self.predicate

- (void)updatePredicateFromFilterButtons {
    NSPredicate *pred = [NSPredicate predicateWithValue:YES];
    
    // Assignee
    if (!_assignee.hidden) {
        id selectedOpt = [self selectedObjectInFilter:_assignee];
        if (selectedOpt != nil) {
            if (selectedOpt == [NSNull null]) {
                pred = [pred and:[NSPredicate predicateWithFormat:@"count(assignees) = 0"]];
            } else {
                pred = [pred and:[NSPredicate predicateWithFormat:@"ANY assignees.login = %@", selectedOpt]];
            }
        }
    }
    
    // Author
    if (!_author.hidden) {
        id selectedOpt = [self selectedObjectInFilter:_author];
        if (selectedOpt != nil) {
            NSAssert([selectedOpt isKindOfClass:[NSString class]], nil);
            pred = [pred and:[NSPredicate predicateWithFormat:@"originator.login = %@", selectedOpt]];
        }
    }
    
    // Repo
    if (!_repo.hidden) {
        Repo *selectedOpt = [self selectedObjectInFilter:_repo];
        if (selectedOpt != nil) {
            NSAssert([selectedOpt isKindOfClass:[Repo class]], nil);
            pred = [pred and:[NSPredicate predicateWithFormat:@"repository.identifier = %@", selectedOpt.identifier]];
        }
    }
    
    // State
    if (!_state.hidden) {
        id closed = [self selectedObjectInFilter:_state];
        if (closed != nil) {
            pred = [pred and:[NSPredicate predicateWithFormat:@"closed = %@", closed]];
        }
    }
    
    // Label
    if (!_label.hidden) {
        NSPredicate *lp = _labelsFilter.labelsPredicate;
        if (lp) {
            pred = [pred and:lp];
        }
    }
    
    // Milestone
    if (!_milestone.hidden) {
        id milestone = [self selectedObjectInFilter:_milestone];
        if (milestone) {
            if (milestone == [NSNull null]) {
                pred = [pred and:[NSPredicate predicateWithFormat:@"milestone = nil"]];
            } else {
                pred = [pred and:[NSPredicate predicateWithFormat:@"milestone.title = %@", milestone]];
            }
        }
    }
    
    // Pull Request
    if (!_pullRequest.hidden) {
        id val = [self selectedObjectInFilter:_pullRequest];
        if (val) {
            pred = [pred and:[NSPredicate predicateWithFormat:@"pullRequest = %@", val]];
        }
    }
    
    self.predicate = pred;
    [self.delegate filterBar:self didUpdatePredicate:pred];
}

#pragma mark - self.predicate => buttons

- (void)updateFilterButtonsFromPredicate {
    [self updateAssigneeMenuStateFromPredicate];
    [self updateAuthorMenuStateFromPredicate];
    [self updateRepoMenuStateFromPredicate];
    [self updateStateMenuStateFromPredicate];
    [self updateLabels];
    [self updateMilestoneMenuStateFromPredicate];
    [self updatePullRequestMenuStateFromPredicate];
}

#pragma mark - API

- (void)clearFilters {
    self.predicate = nil;
    [self updateFilterButtonsFromPredicate];
    [self.delegate filterBar:self didUpdatePredicate:nil];
}

- (void)resetFilters:(NSPredicate *)defaultFilters {
    self.predicate = defaultFilters;
    [self updateFilterButtonsFromPredicate];
    [self.delegate filterBar:self didUpdatePredicate:nil];
}

- (void)removeFromWindow {
    NSInteger idx = NSNotFound;
    NSInteger i = 0;
    for (NSTitlebarAccessoryViewController *acc in self.window.titlebarAccessoryViewControllers) {
        if (acc == self) {
            idx = i;
            break;
        }
        i++;
    }
    if (idx != NSNotFound) {
        [self.window removeTitlebarAccessoryViewControllerAtIndex:idx];
        self.window = nil;
    }
}

- (void)addToWindow:(NSWindow *)window {
    if (window != self.window) {
        if (self.window) {
            [self removeFromWindow];
        }
        self.window = window;
        [window addTitlebarAccessoryViewController:self];
    }
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    for (FilterButton *b in _filters) {
        b.enabled = enabled;
    }
}

#pragma mark - self.basePredicate => button visibility

- (void)setBasePredicate:(NSPredicate *)basePredicate {
    _basePredicate = basePredicate;
    
    _assignee.hidden = [self assigneeLoginInPredicate:basePredicate] != nil;
    _author.hidden = [self authorLoginInPredicate:basePredicate] != nil;
    _repo.hidden = [self repoInPredicate:basePredicate] != nil;
    _state.hidden = [self closedInPredicate:basePredicate] != nil;
    _milestone.hidden = [self milestoneTitleInPredicate:basePredicate] != nil;
    _pullRequest.hidden = !DefaultsPullRequestsEnabled() || [self pullRequestInPredicate:basePredicate] != nil;
    
    [self rebuildMenus];
    [self updatePredicateFromFilterButtons];
    [self updateFilterButtonsFromPredicate];
}

#pragma mark - Layout

- (void)needsButtonLayout {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(layoutButtons) object:nil];
    [self performSelector:@selector(layoutButtons) withObject:nil afterDelay:0 inModes:@[NSRunLoopCommonModes]];
}

- (void)layoutButtons {
    CGRect bounds = self.view.bounds;
    
    CGFloat padX = 6.0;
    
    const NSUInteger maxButtons = 64;
    struct LineInfo {
        CGFloat width;
        NSUInteger buttonCount;
        __unsafe_unretained FilterButton *buttons[maxButtons];
    };
    
    const NSUInteger maxLines = 8;
    struct LineInfo lines[maxLines];
    memset(lines, 0, sizeof(lines));
    
    NSUInteger lineCount = 0;
    
    CGFloat maxLineWidth = CGRectGetWidth(bounds) - (padX * 2.0);
    
    for (FilterButton *b in _filters) {
        if (!b.hidden) {
            [b sizeToFit];
            
            if (lineCount == 0) lineCount++;
            
            NSUInteger li = lineCount-1;
            CGFloat bWidth = b.frame.size.width;
            CGFloat newWidth = lines[li].width + bWidth;
            
            if (lines[li].buttonCount > 0) {
                newWidth += padX;
            }
            
            if (newWidth > maxLineWidth || lines[li].buttonCount == maxButtons ) {
                lineCount++;
                if (lineCount > maxLines) break;
                li++;
                newWidth = bWidth;
            }
            
            lines[li].width = newWidth;
            lines[li].buttons[lines[li].buttonCount] = b;
            lines[li].buttonCount++;
        }
    }
    
    CGFloat viewHeight = LINE_HEIGHT * (CGFloat)lineCount;
    CGRect viewFrame = CGRectMake(0, 0, CGRectGetWidth(bounds), viewHeight);
    
    CGFloat currentHeight = bounds.size.height;
    if (fabs(currentHeight - viewHeight) > 2.0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
            self.fullScreenMinHeight = viewHeight;
            self.view.frame = viewFrame;
        });
    }
    
    for (NSUInteger li = 0; li < lineCount; li++) {
        CGFloat offY = (viewHeight - ((CGFloat)(li+1) * LINE_HEIGHT)) + 2.0;
        CGFloat offX = floor((bounds.size.width - lines[li].width) / 2.0);
        for (NSUInteger bi = 0; bi < lines[li].buttonCount; bi++) {
            FilterButton *b = lines[li].buttons[bi];
            CGRect f = b.frame;
            f.origin.x = offX;
            f.origin.y = offY;
            b.frame = f;
            
            offX += f.size.width + padX;
        }
    }
}

@end

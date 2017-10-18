//
//  LabelsFilterViewController.m
//  Ship
//
//  Created by James Howard on 10/9/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "LabelsFilterViewController.h"

#import "Extras.h"
#import "NSPredicate+Extras.h"
#import "LabelsFilterTableController.h"

@interface LabelsFilterViewController () <LabelsFilterTableControllerDelegate>

@property IBOutlet NSTabView *tabView;
@property IBOutlet NSButton *unlabeledButton;

@property IBOutlet NSTextField *showPredicateCombinedWarningLabel;
@property IBOutlet NSLayoutConstraint *tabToWarningConstraint;
@property IBOutlet NSLayoutConstraint *tabToTopConstraint;

@property LabelsFilterTableController *anyController;
@property LabelsFilterTableController *allController;
@property LabelsFilterTableController *noneController;

@end

@implementation LabelsFilterViewController

- (id)init {
    if (self = [super init]) {
        _anyController = [LabelsFilterTableController new];
        _allController = [LabelsFilterTableController new];
        _noneController = [LabelsFilterTableController new];
        _anyController.delegate = _allController.delegate = _noneController.delegate = self;
        [self view];
    }
    return self;
}

- (NSString *)nibName { return @"LabelsFilterViewController"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[_tabView tabViewItemAtIndex:0] setView:_allController.view];
    [[_tabView tabViewItemAtIndex:1] setView:_anyController.view];
    [[_tabView tabViewItemAtIndex:2] setView:_noneController.view];
}

- (void)viewWillAppear {
    [super viewWillAppear];
    [_anyController clearSearch];
    [_allController clearSearch];
    [_noneController clearSearch];
}

- (NSSize)preferredMaximumSize {
    CGFloat chromeHeight = 428.0 - 292.0;
    if (!_showPredicateCombinedWarning) {
        chromeHeight -= 34.0 + 8.0;
    }
    
    return CGSizeMake(303.0, chromeHeight + _anyController.preferredMaximumSize.height);
}

- (void)updateTabTitles {
    NSSet *anyLabels = [_anyController selectedLabelNames];
    NSSet *allLabels = [_allController selectedLabelNames];
    NSSet *noneLabels = [_noneController selectedLabelNames];
    
    if (allLabels.count > 0) {
        [[_tabView tabViewItemAtIndex:0] setLabel:[NSString localizedStringWithFormat:NSLocalizedString(@"All (%td)", nil), allLabels.count]];
    } else {
        [[_tabView tabViewItemAtIndex:0] setLabel:NSLocalizedString(@"All", nil)];
    }
    if (anyLabels.count > 0) {
        [[_tabView tabViewItemAtIndex:1] setLabel:[NSString localizedStringWithFormat:NSLocalizedString(@"Any (%td)", nil), anyLabels.count]];
    } else {
        [[_tabView tabViewItemAtIndex:1] setLabel:NSLocalizedString(@"Any", nil)];
    }
    if (noneLabels.count > 0) {
        [[_tabView tabViewItemAtIndex:2] setLabel:[NSString localizedStringWithFormat:NSLocalizedString(@"None (%td)", nil), noneLabels.count]];
        DebugLog(@"noneLabels.count = %td", noneLabels.count);
    } else {
        [[_tabView tabViewItemAtIndex:2] setLabel:NSLocalizedString(@"None", nil)];
    }
    
    // NSTabView does not always reliably redraw its tab labels when they change. Toggling the font pokes it.
    // Sigh.
    _tabView.font = [NSFont systemFontOfSize:1.0];
    _tabView.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeRegular]];
}

- (IBAction)clearFilter:(id)sender {
    [self view];
    [_anyController clearSelections];
    [_allController clearSelections];
    [_noneController clearSelections];
    _unlabeledButton.state = NSOffState;
    [self updatePredicateAndNotifyDelegateToClosePopover:YES];
}

- (void)setShowPredicateCombinedWarning:(BOOL)showPredicateCombinedWarning {
    [self view];
    _showPredicateCombinedWarning = showPredicateCombinedWarning;
    if (_showPredicateCombinedWarning) {
        _showPredicateCombinedWarningLabel.hidden = NO;
        _tabToTopConstraint.active = NO;
        _tabToWarningConstraint.active = YES;
    } else {
        _showPredicateCombinedWarningLabel.hidden = YES;
        _tabToWarningConstraint.active = NO;
        _tabToTopConstraint.constant = 8.0;
        _tabToTopConstraint.active = YES;
    }
    [self.view setNeedsLayout:YES];
}

- (NSPredicate *)labelsPredicate {
    if (_unlabeledButton.state == NSOnState) {
        return [NSPredicate predicateWithFormat:@"count(labels) == 0"];
    } else {
        NSArray *anyLabels = [[_anyController selectedLabelNames] allObjects];
        NSArray *allLabels = [[_allController selectedLabelNames] allObjects];
        NSArray *noneLabels = [[_noneController selectedLabelNames] allObjects];
        
        NSMutableArray *parts = [NSMutableArray new];
        if (anyLabels.count > 0) {
            [parts addObject:[NSPredicate predicateWithFormat:@"count(SUBQUERY(labels.name, $name, $name IN %@)) > 0", anyLabels]];
        }
        if (allLabels.count > 0) {
            [parts addObject:[NSPredicate predicateWithFormat:@"count(SUBQUERY(labels.name, $name, $name IN %@)) == count(%@)", allLabels, allLabels]];
        }
        if (noneLabels.count > 0) {
            [parts addObject:[NSPredicate predicateWithFormat:@"count(SUBQUERY(labels.name, $name, $name IN %@)) == 0", noneLabels]];
        }
        
        if (parts.count == 0) {
            return nil;
        } else if (parts.count == 1) {
            return parts[0];
        } else {
            return [NSCompoundPredicate andPredicateWithSubpredicates:parts];
        }
    }
}

- (NSString *)title {
    if (_unlabeledButton.state == NSOnState) {
        return NSLocalizedString(@"Unlabeled", nil);
    } else {
        NSSet *anyLabels = [_anyController selectedLabelNames];
        NSSet *allLabels = [_allController selectedLabelNames];
        NSSet *noneLabels = [_noneController selectedLabelNames];
        
        if (anyLabels.count == 0 && allLabels.count == 0 && noneLabels.count == 0) {
            return @"";
        } else if (anyLabels.count == 1 && allLabels.count == 0 && noneLabels.count == 0) {
            return [anyLabels anyObject];
        } else if (anyLabels.count == 0 && allLabels.count == 1 && noneLabels.count == 0) {
            return [allLabels anyObject];
        } else if (anyLabels.count == 0 && allLabels.count == 0 && noneLabels.count == 1) {
            return [NSString stringWithFormat:NSLocalizedString(@"Not %@", nil), [noneLabels anyObject]];
        } else {
            return NSLocalizedString(@"Multiple", nil);
        }
    }
}

- (void)updatePredicateAndNotifyDelegateToClosePopover:(BOOL)closePopover {
    NSPredicate *predicate = [self labelsPredicate];
    [self.delegate labelsFilterViewController:self didUpdateLabelsPredicate:predicate shouldClosePopover:closePopover];
}

- (IBAction)toggleUnlabeledOnly:(id)sender {
    if (_unlabeledButton.state == NSOnState) {
        [_anyController clearSelections];
        [_allController clearSelections];
        [_noneController clearSelections];
    }
    [self updatePredicateAndNotifyDelegateToClosePopover:YES];
}

- (void)labelsFilterTableController:(LabelsFilterTableController *)controller didUpdateSelectedLabelNames:(NSSet<NSString *> *)selectedLabelNames {
    _unlabeledButton.state = NSOffState;
    [self updateTabTitles];
    [self updatePredicateAndNotifyDelegateToClosePopover:NO];
}


- (void)setLabels:(NSArray<Label *> *)possibleLabels predicate:(NSPredicate *)labelsPredicate {
    
    // NONE: count(SUBQUERY(labels.name, $name, $name IN { ... })) == 0
    // ANY: count(SUBQUERY(labels.name, $name, $name IN { ... })) > 0
    // ALL: count(SUBQUERY(labels.name, $name, $name IN { ... })) == count({ ... })
    // count(labels) == 0
    //
    // Note: I would prefer to have written these queries like this, but alas Core Data doesn't support these:
    // NONE labels.name IN { ... } (sugar for NOT (ANY labels.name IN { ... }))
    // ANY labels.name IN { ... }
    // ALL labels.name IN { ... }
    
    NSArray *predicates = [labelsPredicate predicatesMatchingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        
        if ([evaluatedObject isKindOfClass:[NSComparisonPredicate class]])
        {
            NSComparisonPredicate *c0 = evaluatedObject;
            NSExpression *lhs = c0.leftExpression;
            
            if (lhs.expressionType == NSFunctionExpressionType && [lhs.function isEqualToString:@"count:"])
            {
                NSExpression *subq = [lhs.arguments firstObject];
                if (subq.expressionType == NSSubqueryExpressionType
                    && [subq.collection expressionType] == NSKeyPathExpressionType
                    && [[subq.collection keyPath] isEqualToString:@"labels.name"])
                {
                    // NONE|ANY|ALL
                    return YES;
                } else if (subq.expressionType == NSKeyPathExpressionType
                           && [subq.keyPath isEqualToString:@"labels"])
                {
                    // unlabeled:
                    // count(labels) == 0
                    return YES;
                }
            }
        }
        
        return NO;
    }]];
    
    NSArray *noneLabels = nil;
    NSArray *anyLabels = nil;
    NSArray *allLabels = nil;
    BOOL unlabeled = NO;
    
    for (NSComparisonPredicate *c0 in predicates) {
        NSExpression *lhs = c0.leftExpression;
        NSExpression *rhs = c0.rightExpression;
        NSExpression *subq = [lhs.arguments firstObject];
        if (subq.expressionType == NSSubqueryExpressionType) {
            // NONE|ANY|ALL
            NSAssert([subq.collection expressionType] == NSKeyPathExpressionType, nil);
            NSAssert([[subq.collection keyPath] isEqualToString:@"labels.name"], nil);
            
            NSArray *labels = [((NSComparisonPredicate *)subq.predicate).rightExpression expressionValueWithObject:nil context:NULL];
            
            if (rhs.expressionType == NSConstantValueExpressionType) {
                // NONE|ANY
                NSAssert([[rhs expressionValueWithObject:nil context:nil] isEqual:@0], @"unexpected constant value");
                if (c0.predicateOperatorType == NSEqualToPredicateOperatorType) {
                    noneLabels = labels;
                } else if (c0.predicateOperatorType == NSGreaterThanPredicateOperatorType) {
                    anyLabels = labels;
                } else {
                    NSAssert(NO, @"unexpected predicate operator encountered");
                }
            } else {
                // ALL
                NSAssert(rhs.expressionType == NSFunctionExpressionType, nil);
                allLabels = labels;
            }
        } else {
            unlabeled = YES;
        }
    }
    
    _unlabeledButton.state = unlabeled ? NSOnState : NSOffState;
    if (unlabeled) {
        [_anyController clearSelections];
        [_allController clearSelections];
        [_noneController clearSelections];
    } else {
        [_anyController setLabels:possibleLabels selected:[NSSet setWithArray:anyLabels?:@[]]];
        [_allController setLabels:possibleLabels selected:[NSSet setWithArray:allLabels?:@[]]];
        [_noneController setLabels:possibleLabels selected:[NSSet setWithArray:noneLabels?:@[]]];
    }
    [self updateTabTitles];
}

@end

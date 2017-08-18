//
//  ReviewStateTemplate.m
//  ShipHub
//
//  Created by James Howard on 8/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "ReviewStateTemplate.h"

#import "Account.h"
#import "CompletingTextField.h"
#import "DataStore.h"
#import "Extras.h"
#import "MetadataStore.h"
#import "PRReview.h"

// Review state <state> exists
// Review state <state> does not exist
// Review state <state> exists and reviewer is <user>

@interface ReviewStateTemplate () {
    NSPopUpButton *_statePopup;
    NSPopUpButton *_opPopup;
    CompletingTextField *_userField;
}

@end

@implementation ReviewStateTemplate

- (id)init {
    NSExpression *left = [NSExpression expressionForKeyPath:@"reviews"];
    self = [super initWithLeftExpressions:@[left] rightExpressionAttributeType:NSStringAttributeType modifier:0 operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    return self;
}

- (NSPopUpButton *)opPopup {
    if (!_opPopup) {
        _opPopup = [[NSPopUpButton alloc] initWithFrame:CGRectZero];
        _opPopup.controlSize = NSSmallControlSize;
        [_opPopup setBezelStyle:NSRoundRectBezelStyle];
        
        [_opPopup addItemWithTitle:NSLocalizedString(@"exists", nil)];
        [_opPopup addItemWithTitle:NSLocalizedString(@"does not exist", nil)];
        [_opPopup addItemWithTitle:NSLocalizedString(@"exists and reviewer is", nil)];
        
        [_opPopup sizeToFit];
    }
    return _opPopup;
}

- (NSPopUpButton *)statePopup {
    if (!_statePopup) {
        _statePopup = [[NSPopUpButton alloc] initWithFrame:CGRectZero];
        _statePopup.controlSize = NSSmallControlSize;
        [_statePopup setBezelStyle:NSRoundRectBezelStyle];
        
        // order matches PRReviewState enum
        [_statePopup addItemWithTitle:NSLocalizedString(@"pending", nil)];
        [_statePopup addItemWithTitle:NSLocalizedString(@"approved", nil)];
        [_statePopup addItemWithTitle:NSLocalizedString(@"changes requested", nil)];
        [_statePopup addItemWithTitle:NSLocalizedString(@"commented", nil)];
        [_statePopup addItemWithTitle:NSLocalizedString(@"dismissed", nil)];
        
        [_statePopup sizeToFit];
    }
    return _statePopup;
}

- (CompletingTextField *)userField {
    if (!_userField) {
        CompletingTextField *textField = [[CompletingTextField alloc] initWithFrame:CGRectMake(0, 0, 160.0, 18.0)];
        textField.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
        textField.placeholderString = NSLocalizedString(@"Not Set", nil);
        textField.cancelsOnExternalClick = YES;
        textField.hidden = YES;
        
        __weak __typeof(self) weakSelf = self;
        textField.complete = ^(NSString *text) {
            return [weakSelf complete:text];
        };
        _userField = textField;
    }
    return _userField;
}

- (NSArray *)complete:(NSString *)text {
    NSArray *logins = [[[[DataStore activeStore] metadataStore] allAssignees] arrayByMappingObjects:^id(id obj) {
        return [obj login];
    }];
    if ([text length] == 0) {
        return logins;
    } else {
        return [logins filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[cd] %@", text]];
    }
}

- (NSArray *)templateViews {
    NSMutableArray *views = [[super templateViews] mutableCopy];
    [views removeObjectsInRange:NSMakeRange(1, views.count-1)];
    
    [views addObject:[self statePopup]];
    [views addObject:[self opPopup]];
    [views addObject:[self userField]];
    
    return views;
}

- (NSPredicate *)predicateWithSubpredicates:(NSArray<NSPredicate *> *)subpredicates {
    NSInteger op = [[self opPopup] indexOfSelectedItem];
    PRReviewState state = [[self statePopup] indexOfSelectedItem];
    NSString *userLogin = [[self userField] stringValue];
    
    [[self userField] setHidden:op != 2];
    
    if (op == 0) {
        // review state exists
        return [NSPredicate predicateWithFormat:@"SUBQUERY(reviews, $r, $r.state =[c] %@).@count > 0", PRReviewStateToString(state)];
    } else if (op == 1) {
        // review state does not exist
        return [NSPredicate predicateWithFormat:@"SUBQUERY(reviews, $r, $r.state =[c] %@).@count = 0", PRReviewStateToString(state)];
    } else if (op == 2) {
        // review state exists and reviewer is
        return [NSPredicate predicateWithFormat:@"SUBQUERY(reviews, $r, $r.state =[c] %@ AND $r.user.login = %@).@count > 0", PRReviewStateToString(state), userLogin];
    } else {
        NSAssert(NO, @"Unhandled op %td", op);
        return nil;
    }
}

- (BOOL)parsePredicate:(NSPredicate *)predicate outOp:(NSInteger *)outOp outState:(PRReviewState *)outState outLogin:(NSString **)outLogin
{
    NSInteger op = 0;
    PRReviewState state = 0;
    NSString *login = nil;
    
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c = (id)predicate;
        NSExpression *left = [c leftExpression];
        if (left.expressionType == NSFunctionExpressionType) {
            NSExpression *subq = [left operand];
            if ([subq expressionType] != NSSubqueryExpressionType) {
                return NO;
            }
            
            NSString *collection = [[subq collection] description];
            if (![collection isEqualToString:@"reviews"]) {
                return NO;
            }
            
            NSPredicate *s = [subq predicate];
            NSComparisonPredicate *k = nil;
            
            // op 0, 1, s is NSComparisonPredicate
            // op > 1, s is NSCompoundPredicate
            
            if ([s isKindOfClass:[NSComparisonPredicate class]]) {
                k = (id)s;
                if ([c predicateOperatorType] == NSGreaterThanPredicateOperatorType) {
                    op = 0;
                } else if ([c predicateOperatorType] == NSEqualToPredicateOperatorType) {
                    op = 1;
                } else {
                    return NO;
                }
            } else if ([s isKindOfClass:[NSCompoundPredicate class]]) {
                k = [(NSCompoundPredicate *)s subpredicates][0];
                NSComparisonPredicate *v = [(NSCompoundPredicate *)s subpredicates][1];
                op = 2;
                login = [[v rightExpression] constantValue];
            } else {
                return NO;
            }
            
            state = PRReviewStateFromString([[k rightExpression] constantValue]);
        } else {
            return NO;
        }
    } else {
        return NO;
    }
    
    if (outOp) *outOp = op;
    if (outState) *outState = state;
    if (outLogin) *outLogin = login;
    
    return YES;
}

- (void)setPredicate:(NSPredicate *)predicate {
    NSInteger op = 0;
    PRReviewState state = 0;
    NSString *login = nil;

    [self parsePredicate:predicate outOp:&op outState:&state outLogin:&login];
    
    [[self opPopup] selectItemAtIndex:op];
    [[self statePopup] selectItemAtIndex:state];
    [[self userField] setStringValue:login ?: @""];
    
    [[self userField] setHidden:op <= 1];
    
    // Get super to set the leftmost popup
    [super setPredicate:[NSPredicate predicateWithFormat:@"reviews = nil"]];
}

- (double)matchForPredicate:(NSPredicate *)predicate {
    if ([self parsePredicate:predicate outOp:NULL outState:NULL outLogin:NULL]) {
        return 1.0;
    } else {
        return 0.0;
    }
}

@end

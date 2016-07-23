//
//  PopUpMetadataRowTemplate.m
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "PopUpMetadataRowTemplate.h"

#import "Extras.h"

@interface MyPopUp : NSPopUpButton

@end

@implementation MyPopUp

- (void)selectItemAtIndex:(NSInteger)index {
    [super selectItemAtIndex:index];
}

- (void)selectItem:(NSMenuItem *)item {
    [super selectItem:item];
}

- (void)selectItemWithTitle:(NSString *)title {
    [super selectItemWithTitle:title];
}

@end

@implementation PopUpMetadataRowTemplate {
    NSString *_metadataType;
    NSPopUpButton *_popUp;
}

- (id)initWithMetadataType:(NSString *)type {
    if (self = [super initWithLeftExpressions:@[[NSExpression expressionForKeyPath:type]] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0]) {
        _metadataType = [type copy];
    }
    return self;
}

- (NSArray *)popUpItems {
    return nil;
}

- (NSString *)titleForPopUpItem:(id<PopUpMetadataItem>)item {
    return [item name];
}

- (BOOL)showNotSetItem {
    return YES;
}

- (NSPopUpButton *)popUp {
    if (!_popUp) {
        _popUp = [[MyPopUp alloc] initWithFrame:CGRectMake(0, 0, 160.0, 17.0)];
        [_popUp setBezelStyle:NSRoundRectBezelStyle];
        [_popUp setControlSize:NSSmallControlSize];
        [_popUp setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
        NSMenu *menu = [_popUp menu];
        if ([self showNotSetItem]) {
            [menu addItemWithTitle:NSLocalizedString(@"Not Set", nil) action:nil keyEquivalent:@""];
        }
        for (id<PopUpMetadataItem> item in [self popUpItems]) {
            NSMenuItem *menuItem = [menu addItemWithTitle:[self titleForPopUpItem:item] action:nil keyEquivalent:@""];
            menuItem.representedObject = item;
        }
    }
    return _popUp;
}

- (NSArray *)templateViews {
    NSMutableArray *a = [[super templateViews] mutableCopy];
    [a removeLastObject];
    [a addObject:[self popUp]];
    return a;
}

- (NSPredicate *)predicateWithSubpredicates:(NSArray *)subpredicates {
    NSPredicate * p = [super predicateWithSubpredicates:subpredicates];
    if ([p isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate * comparison = (NSComparisonPredicate *)p;
        NSPredicateOperatorType operator = [comparison predicateOperatorType];
        
        NSMenu *menu = [[self popUp] menu];
        NSInteger idx = [[self popUp] indexOfSelectedItem];
        
        id<PopUpMetadataItem> item = [[menu itemAtIndex:idx] representedObject];

        if (operator == NSEqualToPredicateOperatorType || operator == NSNotEqualToPredicateOperatorType) {
            // If we're doing an equals/not equals comparison, we compare by the identifier
            
            NSExpression *left = [NSExpression expressionForKeyPath:[NSString stringWithFormat:@"%@.identifier", _metadataType]];
            NSExpression *right = [NSExpression expressionForConstantValue:[item identifier]];
            
            p = [NSComparisonPredicate predicateWithLeftExpression:left rightExpression:right modifier:[comparison comparisonPredicateModifier] type:operator options:[comparison options]];
            
        } else {
            // Otherwise, we compare by the name/order(/identifier)
            NSString *identifierKey = [NSString stringWithFormat:@"%@.identifier", _metadataType];
            NSString *orderKey = [NSString stringWithFormat:@"%@.order", _metadataType];
            NSString *nameKey = [NSString stringWithFormat:@"%@.name", _metadataType];
            if (operator == NSLessThanPredicateOperatorType) {
                p = [NSPredicate predicateWithFormat:@"(%K < %ld) OR (%K = %ld AND %K < %@)", orderKey, [item order], orderKey, [item order], nameKey, [item name]];
            } else if (operator == NSGreaterThanPredicateOperatorType) {
                p = [NSPredicate predicateWithFormat:@"(%K > %ld) OR (%K = %ld AND %K > %@)", orderKey, [item order], orderKey, [item order], nameKey, [item name]];
            } else if (operator == NSLessThanOrEqualToPredicateOperatorType) {
                p = [NSPredicate predicateWithFormat:@"(%K < %ld) OR (%K = %ld AND %K < %@) OR (%K = %@)", orderKey, [item order], orderKey, [item order], nameKey, [item name], identifierKey, [item identifier]];
            } else if (operator == NSGreaterThanOrEqualToPredicateOperatorType) {
                p = [NSPredicate predicateWithFormat:@"(%K > %ld) OR (%K = %ld AND %K > %@) OR (%K = %@)", orderKey, [item order], orderKey, [item order], nameKey, [item name], identifierKey, [item identifier]];
            } else {
                NSAssert(NO, @"Unhandled operator type");
            }
        }
    }
    return p;
}

- (void)setPredicate:(NSPredicate *)newPredicate {
    if ([newPredicate isKindOfClass:[NSComparisonPredicate class]]) {
        // ==, !=
        NSComparisonPredicate * comparison = (NSComparisonPredicate *)newPredicate;
        
        NSExpression * right = [comparison rightExpression];
        NSPredicateOperatorType op = [comparison predicateOperatorType];
        NSString *identifier = [right constantValue];
        
        [[self popUp] selectItemMatchingPredicate:[NSPredicate predicateWithFormat:@"representedObject.identifier = %@", identifier]];
        
        if (op == NSEqualToPredicateOperatorType) {
            newPredicate = [NSPredicate predicateWithFormat:@"%K = %@", _metadataType, [[self popUp] titleOfSelectedItem]];
        } else {
            newPredicate = [NSPredicate predicateWithFormat:@"%K != %@", _metadataType, [[self popUp] titleOfSelectedItem]];
        }
    } else if ([newPredicate isKindOfClass:[NSCompoundPredicate class]]) {
        // <, >, <=, >=
        NSCompoundPredicate *compound = (NSCompoundPredicate *)newPredicate;
        NSArray *subpredicates = [compound subpredicates];
        
        NSPredicateOperatorType operator = [[subpredicates firstObject] predicateOperatorType];
        if ([subpredicates count] == 2) {
            // <, >
            
            NSComparisonPredicate *a = [subpredicates firstObject];
            if ([a comparisonPredicateModifier] == NSLessThanPredicateOperatorType) {
                newPredicate = [NSPredicate predicateWithFormat:@"%K < %@", _metadataType, [[self popUp] titleOfSelectedItem]];
            } else {
                newPredicate = [NSPredicate predicateWithFormat:@"%K > %@", _metadataType, [[self popUp] titleOfSelectedItem]];
            }
            
            NSCompoundPredicate *b = [subpredicates lastObject];
            NSComparisonPredicate *b0 = [[b subpredicates] firstObject];
            (void)b0;
            NSComparisonPredicate *b1 = [[b subpredicates] lastObject];
            
            NSNumber *order = [[a rightExpression] constantValue];
            NSString *name = [[b1 rightExpression] constantValue];
            
            [[self popUp] selectItemMatchingPredicate:[NSPredicate predicateWithFormat:@"representedObject.order = %@ AND representedObject.name = %@", order, name]];
        } else {
            NSAssert([subpredicates count] == 3, @"Was expecting 3 subpredicates");
            // <=, >=
            if (operator == NSLessThanPredicateOperatorType) {
                operator = NSLessThanOrEqualToPredicateOperatorType;
            } else if (operator == NSGreaterThanPredicateOperatorType) {
                operator = NSGreaterThanOrEqualToPredicateOperatorType;
            } else {
                NSAssert(NO, @"Was expecting either < or >");
            }
            
            NSComparisonPredicate *a = [subpredicates firstObject];

            NSCompoundPredicate *b = subpredicates[1];
            NSComparisonPredicate *b0 = [[b subpredicates] firstObject];
            (void)b0;
            NSComparisonPredicate *b1 = [[b subpredicates] lastObject];
            
            NSNumber *order = [[a rightExpression] constantValue];
            NSString *name = [[b1 rightExpression] constantValue];
            
            [[self popUp] selectItemMatchingPredicate:[NSPredicate predicateWithFormat:@"representedObject.order = %@ AND representedObject.name = %@", order, name]];
            
            newPredicate = [NSComparisonPredicate predicateWithLeftExpression:[[self leftExpressions] firstObject] rightExpression:[NSExpression expressionForConstantValue:[[self popUp] titleOfSelectedItem]] modifier:[a comparisonPredicateModifier] type:operator options:0];
        }
    }
    [super setPredicate:newPredicate];
}

- (double)matchForPredicate:(NSPredicate *)predicate {
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        // ==, !=
        NSComparisonPredicate * comparison = (NSComparisonPredicate *)predicate;
        
        NSExpression *left = [comparison leftExpression];
        if (left.expressionType != NSKeyPathExpressionType) {
            return 0.0;
        }
        
        NSString *keyPath = [left keyPath];
        
        if ([keyPath isEqualToString:[NSString stringWithFormat:@"%@.identifier", _metadataType]]) {
            return 1.0;
        } else {
            return 0.0;
        }
    } else if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        // <, >, <=, >=
        NSCompoundPredicate *compound = (NSCompoundPredicate *)predicate;
        NSArray *subpredicates = [compound subpredicates];
        
        NSComparisonPredicate *first = [subpredicates firstObject];
        if (![first isKindOfClass:[NSComparisonPredicate class]]) {
            return 0.0;
        }
        NSPredicateOperatorType operator = [first predicateOperatorType];
        if ([subpredicates count] == 2 || [subpredicates count] == 3) {
            // <, >, <=, >=
            if (!(operator == NSLessThanPredicateOperatorType || operator == NSGreaterThanPredicateOperatorType)) {
                return 0.0;
            }
            
            NSExpression *left = [first leftExpression];
            if (left.expressionType != NSKeyPathExpressionType) {
                return 0.0;
            }
            NSString *keyPath = [left keyPath];
            
            if ([keyPath isEqualToString:[NSString stringWithFormat:@"%@.order", _metadataType]]) {
                return 1.0;
            } else {
                return 0.0;
            }
        } else {
            return 0.0;
        }
    } else {
        return 0.0;
    }
}

@end

//
//  FreeformMetadataRowTemplate.m
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "FreeformMetadataRowTemplate.h"
#import "CompletingTextField.h"

#import "Extras.h"

@implementation FreeformMetadataRowTemplate {
    CompletingTextField *_textField;
}

- (id)initWithLeftExpressions:(NSArray *)leftExpressions {
    return [super initWithLeftExpressions:leftExpressions rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSEqualToPredicateOperatorType), @(NSNotEqualToPredicateOperatorType)] options:0];
}

- (CompletingTextField *)textField {
    if (!_textField) {
        CompletingTextField *textField = [[CompletingTextField alloc] initWithFrame:CGRectMake(0, 0, 160.0, 18.0)];
        textField.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
        textField.placeholderString = NSLocalizedString(@"Not Set", nil);
        textField.cancelsOnExternalClick = YES;
        
        __weak __typeof(self) weakSelf = self;
        textField.complete = ^(NSString *text) {
            return [weakSelf complete:text];
        };
        _textField = textField;
    }
    return _textField;
}

- (NSArray *)templateViews {
    NSMutableArray *views = [[super templateViews] mutableCopy];
    
    [views removeLastObject];
    [views addObject:[self textField]];
    
    return views;
}

static BOOL operatorAllowsNil(NSPredicateOperatorType type) {
    return type == NSEqualToPredicateOperatorType || type == NSNotEqualToPredicateOperatorType;
}

- (NSPredicate *)predicateWithSubpredicates:(NSArray *)subpredicates {
    NSPredicate * p = [super predicateWithSubpredicates:subpredicates];
    if ([p isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate * comparison = (NSComparisonPredicate *)p;
        
        NSString *value = [[self textField] stringValue];
        NSString *identifier = [self identifierWithValue:value];
        
        if (identifier == nil && !operatorAllowsNil([comparison predicateOperatorType])) {
            identifier = @"";
        }
        
        NSExpression *right = [NSExpression expressionForConstantValue:identifier];
        
        p = [NSComparisonPredicate predicateWithLeftExpression:[comparison leftExpression]
                                               rightExpression:right
                                                      modifier:[comparison comparisonPredicateModifier]
                                                          type:[comparison predicateOperatorType]
                                                       options:[comparison options]];
        
        // workaround for rdar://27501097 CoreData nil handling in predicates differs from in memory handling
        if (identifier != nil
            && [comparison predicateOperatorType] == NSNotEqualToPredicateOperatorType)
        {
            NSPredicate *orNil = [NSComparisonPredicate predicateWithLeftExpression:[comparison leftExpression]
                                                                    rightExpression:[NSExpression expressionForConstantValue:nil]
                                                                           modifier:NSDirectPredicateModifier
                                                                               type:NSEqualToPredicateOperatorType
                                                                            options:0];
            p = [p or:orNil];
        }
    }
    return p;
}

- (void)setPredicate:(NSPredicate *)newPredicate {
    if ([newPredicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate * comparison = (NSComparisonPredicate *)newPredicate;
        
        NSExpression * right = [comparison rightExpression];
        NSString *rightValue = [right constantValue];
        
        NSString *displayValue = [self valueWithIdentifier:rightValue];
        [[self textField] setStringValue:displayValue ?: @""];
    } else if ([newPredicate isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *compound = (NSCompoundPredicate *)newPredicate;
        NSComparisonPredicate *left = [compound.subpredicates firstObject];
        [self setPredicate:left];
        return;
    }
    [super setPredicate:newPredicate];
}

- (double)matchForPredicate:(NSPredicate *)predicate {
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        return [super matchForPredicate:predicate];
    } else if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        // if it's a compound predicate, it must be exactly of this form:
        // "%K != %@ OR %K == nil"
        NSCompoundPredicate *compound = (NSCompoundPredicate *)predicate;
        
        if (compound.compoundPredicateType != NSOrPredicateType) return 0.0;
        
        NSArray *ps = compound.subpredicates;
        if (ps.count != 2) return 0.0;
        
        NSPredicate *p0 = ps[0];
        NSPredicate *p1 = ps[1];
        
        if (![p0 isKindOfClass:[NSComparisonPredicate class]] || ![p1 isKindOfClass:[NSComparisonPredicate class]]) {
            return 0.0;
        }
        
        NSComparisonPredicate *c0 = (id)p0;
        NSComparisonPredicate *c1 = (id)p1;
        
        if ([super matchForPredicate:c0] == 1.0) {
            if ([c1 predicateOperatorType] == NSEqualToPredicateOperatorType) {
                NSString *kp0 = [[c0 leftExpression] keyPath];
                NSString *kp1 = [[c1 rightExpression] keyPath];
                if ([kp0 isEqualToString:kp1]) {
                    NSExpression *r1 = [c1 rightExpression];
                    if ([r1 expressionType] == NSConstantValueExpressionType && [r1 constantValue] == nil) {
                        return 1.0;
                    }
                }
            }
        }
    }
    return 0.0;
}

- (NSArray *)complete:(NSString *)text {
    return nil;
}
- (NSString *)valueWithIdentifier:(NSString *)identifier {
    return identifier;
}
- (NSString *)identifierWithValue:(NSString *)value {
    return value;
}



@end

//
//  NSPredicate+Extras.m
//  Ship
//
//  Created by James Howard on 7/24/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "NSPredicate+Extras.h"
#import "Extras.h"

@implementation NSPredicate (Folding)

- (NSPredicate *)predicateByFoldingExpressions {
    if ([self isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *c0 = (id)self;
        NSCompoundPredicate *c1 = [[NSCompoundPredicate alloc] initWithType:[c0 compoundPredicateType] subpredicates:[[c0 subpredicates] arrayByMappingObjects:^id(id obj) {
            return [obj predicateByFoldingExpressions];
        }]];
        return c1;
    } else if ([self isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c0 = (id)self;
        if (c0.predicateOperatorType == NSCustomSelectorPredicateOperatorType) {
            return [[NSComparisonPredicate alloc] initWithLeftExpression:[c0.leftExpression foldedExpression] rightExpression:[c0.rightExpression foldedExpression] customSelector:c0.customSelector];
        } else {
            return [[NSComparisonPredicate alloc] initWithLeftExpression:[c0.leftExpression foldedExpression] rightExpression:[c0.rightExpression foldedExpression] modifier:c0.comparisonPredicateModifier type:c0.predicateOperatorType options:c0.options];
        }
    } else {
        return self;
    }
}

@end

@implementation NSExpression (Folding)

- (NSExpression *)foldedExpression {
    @try {
        id value = [self expressionValueWithObject:nil context:nil];
        if (value) {
            return [NSExpression expressionForConstantValue:value];
        } else {
            return self;
        }
    } @catch (id ex) {
        return self;
    }
}

@end

@implementation NSPredicate (Walking)

- (BOOL)syntaxTreeContainsExpressionsMatchingPredicate:(NSPredicate *)predicate {
    if ([self isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *c0 = (id)self;
        for (NSPredicate *subpredicate in [c0 subpredicates]) {
            if ([subpredicate syntaxTreeContainsExpressionsMatchingPredicate:predicate]) {
                return YES;
            }
        }
        return NO;
    } else if ([self isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c0 = (id)self;
        return ([[c0 leftExpression] syntaxTreeContainsExpressionsMatchingPredicate:predicate]) || ([[c0 rightExpression] syntaxTreeContainsExpressionsMatchingPredicate:predicate]);
    } else {
        return NO;
    }
}

@end

@implementation NSExpression (Walking)

- (NSExpression *)operandOrNil {
    switch (self.expressionType) {
        case NSFunctionExpressionType:
            return [self operand];
        default:
            return nil;
    }
}

- (NSArray *)argumentsOrNil {
    switch (self.expressionType) {
        case NSFunctionExpressionType:
            return [self arguments];
        default:
            return nil;
    }
}

- (NSPredicate *)predicateOrNil {
    switch (self.expressionType) {
        case NSSubqueryExpressionType:
            return [self predicate];
        default:
            return nil;
    }
}

- (NSExpression *)collectionOrNil {
    NSExpression *col = nil;
    switch (self.expressionType) {
        case NSAggregateExpressionType:
        case NSSubqueryExpressionType:
            col = [self collection];
            break;
        default:
            break;
    }
    if ([col isKindOfClass:[NSExpression class]]) {
        return col;
    }
    return nil;
}

- (BOOL)syntaxTreeContainsExpressionsMatchingPredicate:(NSPredicate *)predicate {
    if ([predicate evaluateWithObject:self]) {
        return YES;
    }
    
    return [[self operandOrNil] syntaxTreeContainsExpressionsMatchingPredicate:predicate]
    || [[self predicateOrNil] syntaxTreeContainsExpressionsMatchingPredicate:predicate]
    || [[self collectionOrNil] syntaxTreeContainsExpressionsMatchingPredicate:predicate]
    || [[self argumentsOrNil] containsObjectMatchingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [evaluatedObject syntaxTreeContainsExpressionsMatchingPredicate:predicate];
    }]];
}

@end
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

- (NSPredicate *)coreDataPredicate {
    NSPredicate *folded = [self predicateByFoldingExpressions];
    return [folded predicateByRewriting:^NSPredicate *(NSPredicate *original) {
        if ([original isKindOfClass:[NSComparisonPredicate class]]) {
            NSComparisonPredicate *c0 = (id)original;
            if (c0.comparisonPredicateModifier == NSAllPredicateModifier) {
                // rdar://26948853 Core Data does not support predicates of the form ALL <toMany> IN <set>
                // Rewrite ALL foo = bar to
                // COUNT(SUBQUERY(foo, $i, $i = bar)) = COUNT(foo)
                
                NSComparisonPredicate *subqP = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForVariable:@"$i"] rightExpression:c0.rightExpression modifier:NSDirectPredicateModifier type:c0.predicateOperatorType options:c0.options];
                
                NSExpression *subq = [NSExpression expressionForSubquery:c0.leftExpression usingIteratorVariable:@"$i" predicate:subqP];
                
                NSExpression *lhs = [NSExpression expressionForFunction:@"count:" arguments:@[subq]];
                NSExpression *rhs = [NSExpression expressionForFunction:@"count:" arguments:@[c0.leftExpression]];
                
                return [NSComparisonPredicate predicateWithLeftExpression:lhs rightExpression:rhs modifier:NSDirectPredicateModifier type:NSEqualToPredicateOperatorType options:0];
            }
        }
        
        return original;
    }];
}

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

- (NSPredicate *)predicateByRewriting:(PredicateRewriter)rewriter {
    if ([self isKindOfClass:[NSCompoundPredicate class]]) {
        NSPredicate *rewritten = rewriter(self);
        
        if (rewritten != self) {
            return rewritten;
        } else {
            NSCompoundPredicate *c0 = (id)self;
            NSArray *subpredicates = [c0.subpredicates arrayByMappingObjects:^id(id obj) {
                return [obj predicateByRewriting:rewriter];
            }];
            NSCompoundPredicate *result = [[NSCompoundPredicate alloc] initWithType:c0.compoundPredicateType subpredicates:subpredicates];
            return result;
        }
    } else {
        NSPredicate *result = rewriter(self);
        return result;
    }
}

- (void)predicatesMatchingPredicate:(NSPredicate *)predicate accum:(NSMutableArray *)accum
{
    if ([predicate evaluateWithObject:self]) {
        [accum addObject:self];
    }
    if ([self isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *c0 = (id)self;
        
        for (NSPredicate *subpredicate in [c0 subpredicates]) {
            [subpredicate predicatesMatchingPredicate:predicate accum:accum];
        }
    }
}

- (NSArray *)predicatesMatchingPredicate:(NSPredicate *)predicate {
    NSMutableArray *accum = [NSMutableArray new];
    [self predicatesMatchingPredicate:predicate accum:accum];
    return accum;
}

+ (NSPredicate *)predicateMatchingComparisonPredicateWithKeyPath:(NSString *)keyPath {
    return [NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if ([evaluatedObject isKindOfClass:[NSComparisonPredicate class]]) {
            NSComparisonPredicate *c0 = evaluatedObject;
            NSExpression *lhs = c0.leftExpression;
            NSExpression *rhs = c0.rightExpression;
            
            return (lhs.expressionType == NSKeyPathExpressionType && [[lhs keyPath] isEqualToString:keyPath]) || (rhs.expressionType == NSKeyPathExpressionType && [[rhs keyPath] isEqualToString:keyPath]);
        }
        return NO;
    }];
}

// Walk from root and if self is found anywhere in root, return the NSCompoundPredicate
// that contains self (if it exists).
- (NSCompoundPredicate *)parentPredicateInTree:(NSPredicate *)root {
    NSMutableArray *stack = [NSMutableArray new];
    [stack addObject:root];
    
    while ([stack count] > 0) {
        NSPredicate *p = [stack lastObject];
        [stack removeLastObject];
        
        if ([p isKindOfClass:[NSCompoundPredicate class]]) {
            NSCompoundPredicate *c0 = (id)p;
            if ([c0.subpredicates containsObject:self]) {
                return c0;
            }
            [stack addObjectsFromArray:c0.subpredicates];
        }
    }
    
    return nil;
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
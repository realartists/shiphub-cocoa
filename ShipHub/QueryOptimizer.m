//
//  QueryOptimizer.m
//  ShipHub
//
//  Created by James Howard on 9/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "QueryOptimizer.h"

#import "Extras.h"
#import "NSPredicate+Extras.h"

@implementation QueryOptimizer

static BOOL IsAnyKeypathEqualConstantPredicate(NSPredicate *predicate, NSString **keypath, id *constant) {
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c = (id)predicate;
        if (c.predicateOperatorType == NSEqualToPredicateOperatorType &&
            c.comparisonPredicateModifier == NSAnyPredicateModifier &&
            c.leftExpression.expressionType == NSKeyPathExpressionType &&
            c.rightExpression.expressionType == NSConstantValueExpressionType)
        {
            if (keypath) *keypath = c.leftExpression.keyPath;
            if (constant) *constant = c.rightExpression.constantValue;
            return YES;
        }
    }
    if (keypath) *keypath = nil;
    if (constant) *constant = nil;
    return NO;
}

static BOOL IsAnyKeypathOpConstantPredicate(NSPredicate *predicate, NSString **keypath, NSPredicateOperatorType *op, id *constant)
{
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c = (id)predicate;
        if (c.comparisonPredicateModifier == NSAnyPredicateModifier &&
            c.leftExpression.expressionType == NSKeyPathExpressionType &&
            c.rightExpression.expressionType == NSConstantValueExpressionType)
        {
            if (keypath) *keypath = c.leftExpression.keyPath;
            if (op) *op = c.predicateOperatorType;
            if (constant) *constant = c.rightExpression.constantValue;
            return YES;
        }
    }
    if (keypath) *keypath = nil;
    if (op) *op = 0;
    if (constant) *constant = nil;
    return NO;
}

typedef NSPredicate *(CompoundPredicateOptimizer)(NSCompoundPredicate *);

static NSPredicate *OptimizeOrAnyPredicate(NSCompoundPredicate *predicate) {
    if (predicate.subpredicates.count < 2 || predicate.compoundPredicateType != NSOrPredicateType) return predicate;
    
    // Find subpredicates of the form "ANY key.path = constant" and rewrite them as:
    // ANY key.path IN {...}
    
    NSMutableDictionary *candidates = nil;
    for (NSPredicate *sub in predicate.subpredicates) {
        NSString *keypath = nil;
        id constant = nil;
        if (IsAnyKeypathEqualConstantPredicate(sub, &keypath, &constant)) {
            if (!candidates) {
                candidates = [NSMutableDictionary new];
            }
            if (!candidates[keypath]) {
                candidates[keypath] = [NSMutableArray new];
            }
            [candidates[keypath] addObject:constant?:[NSNull null]];
        }
    }
    
    if ([candidates count]) {
        NSMutableArray *terms = [[predicate.subpredicates filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return !IsAnyKeypathEqualConstantPredicate(evaluatedObject, NULL, NULL);
        }]] mutableCopy];
        
        for (NSString *keypath in candidates) {
            NSPredicate *opt = [NSPredicate predicateWithFormat:@"ANY %K IN %@", keypath, candidates[keypath]];
            [terms addObject:opt];
        }
        
        return [NSCompoundPredicate orPredicateWithSubpredicates:terms];
    }
    
    return predicate;
}

static NSPredicate *WorkaroundNotAnyPredicate(NSCompoundPredicate *predicate) {
    if (predicate.compoundPredicateType != NSNotPredicateType) return predicate;
    
    NSArray *subpredicates = predicate.subpredicates;
    NSCAssert(subpredicates.count == 1, nil);
    if (subpredicates.count != 1) return predicate;
    
    NSCompoundPredicate *sub = [subpredicates firstObject];
    if (!([sub isKindOfClass:[NSCompoundPredicate class]])) {
        sub = [NSCompoundPredicate orPredicateWithSubpredicates:@[sub]];
    }
    if (sub.compoundPredicateType != NSOrPredicateType) {
        return predicate;
    }
    
    // Find subpredicates of the form NOT (ANY key.path OP constant[OR ANY key.path OP constant])
    // and rewrite them as either:
    // subquery(key.path, $x, $x IN {...}).@count = 0 [AND (remaining terms)]
    // OR
    // subquery(key.path, $x, $x OP constant[OR $x OP constant]).@count = 0 [AND (remaining terms)]
    
    
    NSMutableDictionary *eqCandidates = nil;
    NSMutableDictionary *otherCandidates = nil;
    for (NSPredicate *term in sub.subpredicates) {
        NSString *keypath = nil;
        NSPredicateOperatorType op = NSEqualToPredicateOperatorType;
        id constant = nil;
        if (IsAnyKeypathEqualConstantPredicate(term, &keypath, &constant)) {
            if (!eqCandidates) {
                eqCandidates = [NSMutableDictionary new];
            }
            if (!eqCandidates[keypath]) {
                eqCandidates[keypath] = [NSMutableArray new];
            }
            [eqCandidates[keypath] addObject:constant?:[NSNull null]];
        } else if (IsAnyKeypathOpConstantPredicate(term, &keypath, &op, &constant)) {
            if (!otherCandidates) {
                otherCandidates = [NSMutableDictionary new];
            }
            if (!otherCandidates[keypath]) {
                otherCandidates[keypath] = [NSMutableArray new];
            }
            [otherCandidates[keypath] addObject:term];
        }
    }
    
    if ([eqCandidates count] > 0 || [otherCandidates count] > 0) {
        NSArray *unmodifiedTerms = [sub.subpredicates filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return !IsAnyKeypathOpConstantPredicate(evaluatedObject, NULL, NULL, NULL); // covers both eq and other operators
        }]];
        
        NSMutableArray *terms = [NSMutableArray new];
        if (unmodifiedTerms.count == 1) {
            [terms addObject:[NSCompoundPredicate notPredicateWithSubpredicate:[unmodifiedTerms firstObject]]];
        } else if (unmodifiedTerms.count > 1) {
            [terms addObject:[NSCompoundPredicate notPredicateWithSubpredicate:[NSCompoundPredicate orPredicateWithSubpredicates:unmodifiedTerms]]];
        }
        
        for (NSString *keypath in eqCandidates) {
            NSPredicate *opt = [NSPredicate predicateWithFormat:@"count(subquery(%K, $x, $x IN %@)) = 0", keypath, eqCandidates[keypath]];
            [terms addObject:opt];
        }
        
        for (NSString *keypath in otherCandidates) {
            NSArray *preds = otherCandidates[keypath];
            NSExpression *left = [NSExpression expressionForVariable:@"x"];
            preds = [preds arrayByMappingObjects:^id(NSComparisonPredicate *a) {
                return [[NSComparisonPredicate alloc] initWithLeftExpression:left rightExpression:a.rightExpression modifier:NSDirectPredicateModifier type:a.predicateOperatorType options:a.options];
            }];
            NSExpression *subq = [NSExpression expressionForSubquery:[NSExpression expressionForKeyPath:keypath] usingIteratorVariable:@"x" predicate:[[NSCompoundPredicate alloc] initWithType:NSOrPredicateType subpredicates:preds]];
            NSExpression *count = [NSExpression expressionForFunction:@"count:" arguments:@[subq]];
            NSPredicate *opt = [[NSComparisonPredicate alloc] initWithLeftExpression:count rightExpression:[NSExpression expressionForConstantValue:@0] modifier:NSDirectPredicateModifier type:NSEqualToPredicateOperatorType options:0];
            [terms addObject:opt];
        }
        
        NSPredicate *repl = [NSCompoundPredicate andPredicateWithSubpredicates:terms];
        DebugLog(@"rewrote %@ to %@", predicate, repl);
        return repl;
    }
    return predicate;
}

+ (NSPredicate *)optimizeIssuesPredicate:(NSPredicate *)predicate {
    NSPredicate *rewrite = [predicate predicateByRewriting:^NSPredicate *(NSPredicate *original) {
        if ([original isKindOfClass:[NSComparisonPredicate class]]) {
            NSComparisonPredicate *c = (id)original;
            NSExpression *lhs = [c leftExpression];
            NSExpression *rhs = [c rightExpression];
            
            // Optimize state == string => closed == BOOL
            if (lhs.expressionType == NSKeyPathExpressionType &&
                rhs.expressionType == NSConstantValueExpressionType &&
                c.predicateOperatorType == NSEqualToPredicateOperatorType &&
                c.comparisonPredicateModifier == 0 &&
                [lhs.keyPath isEqualToString:@"state"])
            {
                static dispatch_once_t onceToken;
                static NSPredicate *openPred;
                static NSPredicate *closedPred;
                dispatch_once(&onceToken, ^{
                    openPred = [NSPredicate predicateWithFormat:@"closed == NO"];
                    closedPred = [NSPredicate predicateWithFormat:@"closed == YES"];
                });
                if ([rhs.constantValue isEqualToString:@"open"]) {
                    return openPred;
                } else {
                    return closedPred;
                }
            }
        } else if ([original isKindOfClass:[NSCompoundPredicate class]]) {
            NSCompoundPredicate *c = (id)original;
            NSPredicate *opt = c;

#if 0
            CompoundPredicateOptimizer *optimizers[] = { &WorkaroundNotAnyPredicate, &OptimizeOrAnyPredicate };
            for (NSUInteger i = 0; i < sizeof(optimizers) / sizeof(CompoundPredicateOptimizer *); i++) {
                CompoundPredicateOptimizer *optimizer = optimizers[i];
                opt = optimizer(c);
                if (opt != c) break;
            }
#endif
            
            // The above loop causes ARC to get confused and leak memory.
            // The below if construct is logically the same as the above code, but does not leak memory.
            // Go figure.
            
            opt = WorkaroundNotAnyPredicate(c);
            if (opt == c) {
                opt = OptimizeOrAnyPredicate(c);
            }
            
            if (opt != c) {
                DebugLog(@"Rewrote %@ to %@", c, opt);
            }
            return opt;
        }
        return original;
    }];
    return rewrite;
}

@end

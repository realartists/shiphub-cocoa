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

static NSPredicate *OptimizeOrAnyPredicate(NSCompoundPredicate *predicate) {
    if (predicate.subpredicates.count < 2 || predicate.compoundPredicateType != NSOrPredicateType) return predicate;
    
    // Find subpredicates of the form "ANY key.path = constant" and rewrite them as:
    // ANY key.path IN {...}
    
    NSMutableDictionary *candidates = [NSMutableDictionary new];
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
            [candidates[keypath] addObject:constant];
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
            NSPredicate *opt = OptimizeOrAnyPredicate((NSCompoundPredicate *)original);
            return opt;
        }
        return original;
    }];
    return rewrite;
}

@end

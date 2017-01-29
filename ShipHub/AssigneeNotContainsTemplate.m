//
//  AssigneeNotContainsTemplate.m
//  ShipHub
//
//  Created by James Howard on 1/27/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "AssigneeNotContainsTemplate.h"

#import "CompletingTextField.h"

@implementation AssigneeNotContainsTemplate

- (id)init {
    if (self = [super initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"assignees.login"]] rightExpressionAttributeType:NSStringAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSNotEqualToPredicateOperatorType)] options:0])
    {
        
    }
    return self;
}

- (NSPredicate *)predicateWithSubpredicates:(NSArray<NSPredicate *> *)subpredicates
{
    NSString *val = [[self textField] stringValue];
    if ([val length]) {
        return [NSPredicate predicateWithFormat:@"count:(SUBQUERY(assignees, $a, $a.login = %@)) == 0", val];
    } else {
        return [NSPredicate predicateWithFormat:@"count:(assignees) != 0"];
    }
}

- (void)setPredicate:(NSPredicate *)predicate {
    NSAssert([self matchForPredicate:predicate] == 1.0, nil);
    
    NSString *login = nil;
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c0 = (id)predicate;
        NSExpression *lhs = c0.leftExpression;
        NSExpression *arg = [lhs.arguments firstObject];
        
        NSPredicate *p = nil;
        
        if (arg.expressionType == NSSubqueryExpressionType) {
            NSComparisonPredicate *subp = (id)arg.predicate;
            NSString *v = [subp.rightExpression constantValue];
            [[self textField] setStringValue:v];
            p = [NSPredicate predicateWithFormat:@"assignees.login != %@", v];
        } else {
            NSAssert(arg.expressionType == NSKeyPathExpressionType, nil);
            [[self textField] setStringValue:@""];
            p = [NSPredicate predicateWithFormat:@"assignees.login != nil"];
        }
        
        [super setPredicate:p];
    } else if ([self isOldStyleNotContainsPredicate:predicate login:&login]) {
        [[self textField] setStringValue:login];
        [super setPredicate:[NSPredicate predicateWithFormat:@"assignees.login != %@", login]];
    }
}

- (BOOL)isOldStyleNotContainsPredicate:(NSPredicate *)predicate login:(NSString *__autoreleasing *)outLogin {
    // ALL assignees.login != "james-howard" OR ALL assignees.login == nil
    if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *c0 = (id)predicate;
        
        if (c0.compoundPredicateType == NSOrPredicateType && c0.subpredicates.count == 2) {
            
            NSPredicate *lhp = [c0.subpredicates firstObject];
            NSPredicate *rhp = [c0.subpredicates lastObject];
            
            if ([lhp isKindOfClass:[NSComparisonPredicate class]]
                && [rhp isKindOfClass:[NSComparisonPredicate class]])
            {
                NSComparisonPredicate *c1 = (id)lhp;
                NSComparisonPredicate *c2 = (id)rhp;
                
                if (c1.comparisonPredicateModifier == NSAllPredicateModifier
                    && c2.comparisonPredicateModifier == NSAllPredicateModifier
                    && c1.predicateOperatorType == NSNotEqualToPredicateOperatorType
                    && c2.predicateOperatorType == NSEqualToPredicateOperatorType)
                {
                    NSExpression *lhs1 = [c1 leftExpression];
                    NSExpression *rhs1 = [c1 rightExpression];
                    
                    NSExpression *lhs2 = [c2 leftExpression];
                    NSExpression *rhs2 = [c2 rightExpression];
                    
                    if (lhs1.expressionType == NSKeyPathExpressionType
                        && [lhs1.keyPath isEqualToString:@"assignees.login"]
                        && rhs1.expressionType == NSConstantValueExpressionType
                        && lhs2.expressionType == NSKeyPathExpressionType
                        && [lhs2.keyPath isEqualToString:@"assignees.login"]
                        && rhs2.expressionType == NSConstantValueExpressionType
                        && rhs2.constantValue == nil)
                    {
                        if (outLogin) {
                            *outLogin = rhs1.constantValue;
                        }
                        return YES;
                    }
                }
            }
        }
    }
    return NO;
}

- (double)matchForPredicate:(NSPredicate *)predicate {
    // predicate is of the form:
    // COUNT(SUBQUERY(assignees.login, $a, $a == $val)) == 0
    // OR
    // COUNT(assignees) == 0
    
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c0 = (id)predicate;
        NSExpression *lhs = c0.leftExpression;
        NSExpression *rhs = c0.rightExpression;
        NSPredicateOperatorType op = c0.predicateOperatorType;
        
        if (op == NSEqualToPredicateOperatorType
            && lhs.expressionType == NSFunctionExpressionType
            && rhs.expressionType == NSConstantValueExpressionType
            && [rhs.constantValue isEqual:@0]) {
            
            lhs = [lhs.arguments firstObject];
            
            if (lhs.expressionType == NSSubqueryExpressionType
                && [lhs.collection expressionType] == NSKeyPathExpressionType
                && [[lhs.collection keyPath] isEqualToString:@"assignees"])
            {
                NSComparisonPredicate *nePred = (id)lhs.predicate;
                if (nePred.predicateOperatorType == NSEqualToPredicateOperatorType) {
                    return 1.0;
                }
            }
        } else if (op == NSNotEqualToPredicateOperatorType
                   && lhs.expressionType == NSFunctionExpressionType
                   && rhs.expressionType == NSConstantValueExpressionType
                   && [rhs.constantValue isEqual:@0]) {
            
            lhs = [lhs.arguments firstObject];
            
            if (lhs.expressionType == NSKeyPathExpressionType
                && ([lhs.keyPath isEqualToString:@"assignees"] || [lhs.keyPath isEqualToString:@"assignees.login"])) {
                return 1.0;
            }
        }
    }
    if ([self isOldStyleNotContainsPredicate:predicate login:NULL]) {
        return 1.0;
    }
    return 0.0;
}

@end

//
//  DataStore+IssuesPredicate.m
//  Ship
//
//  Created by James Howard on 12/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "DataStore+IssuesPredicate.h"

#import "Billing.h"
#import "Extras.h"
#import "NSPredicate+Extras.h"
#import "QueryOptimizer.h"
#import "DataStoreInternal.h"

@implementation DataStore (IssuesPredicate)

static BOOL IsComplexIssueSubqueryPredicateOperator(NSPredicateOperatorType op) {
    switch (op) {
        case NSEqualToPredicateOperatorType:
        case NSNotEqualToPredicateOperatorType:
        case NSInPredicateOperatorType:
            return NO;
        default:
            return YES;
    }
}

- (BOOL)isComplexIssueSubquery:(NSExpression *)expr entityName:(NSString **)outEntityName entityProperty:(NSString **)outEntityProperty entityPredicate:(NSPredicate **)outEntityPredicate {
    
    if (outEntityName) *outEntityName = NULL;
    if (outEntityProperty) *outEntityProperty = NULL;
    if (outEntityPredicate) *outEntityPredicate = NULL;
    
    NSExpression *keypathExpr = [expr collection];
    if (![keypathExpr isKindOfClass:[NSExpression class]] || keypathExpr.expressionType != NSKeyPathExpressionType) {
        return NO;
    }
    
    NSString *keypath = keypathExpr.keyPath;
    
    NSArray *parts = [keypath componentsSeparatedByString:@"."];
    NSString *prefix = parts[0];
    NSString *suffix = nil;
    if (parts.count > 1) {
        suffix = [keypath substringFromIndex:[prefix length]+1];
    }
    
    NSString *variable = expr.variable;
    
    NSPredicate *predicate = expr.predicate;
    
    __block BOOL useRewrite = NO;
    NSPredicate *rewrite = [predicate predicateByRewriting:^NSPredicate *(NSPredicate *original) {
        if ([original isKindOfClass:[NSComparisonPredicate class]]) {
            NSComparisonPredicate *c0 = (id)original;
            NSPredicateOperatorType op = c0.predicateOperatorType;
            useRewrite = useRewrite || IsComplexIssueSubqueryPredicateOperator(op);
            
            NSExpression *lhs = c0.leftExpression;
            
            // expect lhs to be like $x[.key.path]
            // want to rewrite it like SELF.keypath1.keypath2
            
            NSExpression *newLHS = nil;
            if (lhs.expressionType == NSVariableExpressionType && [lhs.variable isEqualToString:variable]) {
                if ([suffix length]) {
                    newLHS = [NSExpression expressionForKeyPath:suffix];
                } else {
                    newLHS = [NSExpression expressionForEvaluatedObject];
                }
            } else if (lhs.expressionType == NSKeyPathExpressionType && lhs.operand.expressionType == NSVariableExpressionType && [lhs.operand.variable isEqualToString:variable])
            {
                if ([suffix length]) {
                    NSString *newKeypath = [suffix stringByAppendingFormat:@".%@", lhs.keyPath];
                    newLHS = [NSExpression expressionForKeyPath:newKeypath];
                } else {
                    newLHS = lhs;
                }
            }
            
            if (newLHS) {
                NSComparisonPredicate *c1 = [NSComparisonPredicate predicateWithLeftExpression:newLHS rightExpression:c0.rightExpression modifier:c0.comparisonPredicateModifier type:c0.predicateOperatorType options:c0.options];
                return c1;
            }
        }
        return original;
    }];
    
    if (useRewrite) {
        NSEntityDescription *issueEntity = self.mom.entitiesByName[@"LocalIssue"];
        NSEntityDescription *subqCollectionEntity = issueEntity.relationshipsByName[prefix].destinationEntity;
        if (!subqCollectionEntity) {
            ErrLog(@"Could not find related entity on LocalIssue for name %@", prefix);
            return NO;
        }
        if (outEntityName) *outEntityName = subqCollectionEntity.name;
        if (outEntityProperty) *outEntityProperty = prefix;
        if (outEntityPredicate) *outEntityPredicate = rewrite;
        return YES;
    }
    
    return NO;
}

- (NSPredicate *)simplifyComplexIssuePredicateSubqueries:(NSPredicate *)basePredicate moc:(NSManagedObjectContext *)moc {
    return [basePredicate predicateByRewriting:^NSPredicate *(NSPredicate *original) {
        // look for expressions of the form count(subquery(keypath, $x, $x OP expr [OR|AND ...])) where OP is not one of {IN, =, !=}
        if ([original isKindOfClass:[NSComparisonPredicate class]]) {
            NSComparisonPredicate *c0 = (id)original;
            NSString *entityName = nil;
            NSString *entityProperty = nil;
            NSPredicate *entityPredicate = nil;
            if (c0.leftExpression.expressionType == NSFunctionExpressionType
                && [c0.leftExpression.function isEqualToString:@"count:"]
                && [c0.leftExpression.arguments.firstObject expressionType] == NSSubqueryExpressionType
                && [self isComplexIssueSubquery:c0.leftExpression.arguments.firstObject entityName:&entityName entityProperty:&entityProperty entityPredicate:&entityPredicate])
            {
                NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entityName];
                fetch.predicate = entityPredicate;
                NSError *error = nil;
                NSArray *matches = [moc executeFetchRequest:fetch error:&error];
                if (error) {
                    ErrLog(@"%@", error);
                    return original;
                }
                
                NSComparisonPredicate *subqP = [NSComparisonPredicate predicateWithLeftExpression:[NSExpression expressionForVariable:@"x"] rightExpression:[NSExpression expressionForConstantValue:matches] modifier:NSDirectPredicateModifier type:NSInPredicateOperatorType options:0];
                NSExpression *newSubq = [NSExpression expressionForSubquery:[NSExpression expressionForKeyPath:entityProperty] usingIteratorVariable:@"x" predicate:subqP];
                
                NSExpression *newCount = [NSExpression expressionForFunction:@"count:" arguments:@[newSubq]];
                
                NSComparisonPredicate *c1 = [NSComparisonPredicate predicateWithLeftExpression:newCount rightExpression:c0.rightExpression modifier:c0.comparisonPredicateModifier type:c0.predicateOperatorType options:c0.options];
                DebugLog(@"Rewrote %@ to %@", c0, c1);
                return c1;
            }
        }
        return original;
    }];
}

- (NSPredicate *)issuesPredicate:(NSPredicate *)basePredicate moc:(NSManagedObjectContext *)moc {
    NSPredicate *extra = nil;
    if (self.billing.limited) {
        if (DefaultsPullRequestsEnabled()) {
            extra = [NSPredicate predicateWithFormat:@"repository.private = NO AND repository.disabled = NO && repository.hidden = nil AND repository.fullName != nil"];
        } else {
            extra = [NSPredicate predicateWithFormat:@"repository.private = NO AND repository.disabled = NO && repository.hidden = nil AND repository.fullName != nil AND pullRequest = NO"];
        }
    } else {
        if (DefaultsPullRequestsEnabled()) {
            extra = [NSPredicate predicateWithFormat:@"repository.disabled = NO AND repository.hidden = nil AND repository.fullName != nil"];
        } else {
            extra = [NSPredicate predicateWithFormat:@"repository.disabled = NO AND repository.hidden = nil AND repository.fullName != nil AND pullRequest = NO"];
        }
    }
    
    NSPredicate *rewrite = [QueryOptimizer optimizeIssuesPredicate:basePredicate];
    rewrite = [self simplifyComplexIssuePredicateSubqueries:rewrite moc:moc];
    
    return [[rewrite coreDataPredicate] and:extra];
}

@end

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

static NSString *AnyAssigneeLogin(NSPredicate *predicate) {
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c = (id)predicate;
        if (c.predicateOperatorType == NSEqualToPredicateOperatorType &&
            c.comparisonPredicateModifier == NSAnyPredicateModifier &&
            c.leftExpression.expressionType == NSKeyPathExpressionType &&
            [c.leftExpression.keyPath isEqualToString:@"assignees.login"] &&
            c.rightExpression.expressionType == NSConstantValueExpressionType)
        {
            NSString *login = c.rightExpression.constantValue;
            return login;
        }
    }
    return nil;
}

static BOOL AllSubpredicatesAreAnyAssignee(NSCompoundPredicate *predicate, NSArray *__autoreleasing* assigneeLogins) {
    if (predicate.subpredicates.count < 2 || predicate.compoundPredicateType != NSOrPredicateType) return NO;
    
    NSMutableArray *logins = nil;
    for (NSPredicate *sub in predicate.subpredicates) {
        NSString *login = nil;
        if ((login = AnyAssigneeLogin(sub)) != nil) {
            if (!logins) {
                logins = [NSMutableArray new];
            }
            [logins addObject:login];
        } else {
            return NO;
        }
    }
    
    if (assigneeLogins) *assigneeLogins = logins;
    return YES;
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
            NSArray *anyAssigneeLogins = nil;
            if (AllSubpredicatesAreAnyAssignee((id)original, &anyAssigneeLogins)) {
                // rewrite a block of (ANY assignees.login = "A" OR ANY assignees.login = "B" OR ...)
                // into (ANY assignees.login IN {"A", "B", ...})
                return [NSPredicate predicateWithFormat:@"ANY assignees.login IN %@", anyAssigneeLogins];
            }
        }
        return original;
    }];
    return rewrite;
}

@end

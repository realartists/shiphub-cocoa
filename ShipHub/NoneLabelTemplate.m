//
//  NoneLabelTemplate.m
//  ShipHub
//
//  Created by James Howard on 7/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "NoneLabelTemplate.h"

@implementation NoneLabelTemplate

- (id)init {
    self = [super initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"labels.name"]] rightExpressionAttributeType:NSStringAttributeType modifier:NSAllPredicateModifier operators:@[@(NSNotEqualToPredicateOperatorType)] options:0];
    return self;
}

- (NSPredicate *)predicateWithSubpredicates:(NSArray *)subpredicates {
    NSMenu *menu = [[self popUp] menu];
    NSInteger idx = [[self popUp] indexOfSelectedItem];
    
    NSString *item = [[menu itemAtIndex:idx] representedObject];
    
    // AKA: ALL labels.name != "foo" (which CoreData cannot execute)
    return [NSPredicate predicateWithFormat:@"count(SUBQUERY(labels, $l, $l.name = %@)) == 0", item];
}

- (void)setPredicate:(NSPredicate *)predicate {
    NSComparisonPredicate *c0 = (id)predicate;
    NSExpression *lhs = c0.leftExpression;
    NSExpression *subq = [lhs.arguments firstObject];
    
    NSComparisonPredicate *eqPred = (NSComparisonPredicate *)subq.predicate;
    NSExpression *rhs = eqPred.rightExpression;
    
    NSString *labelName = [rhs expressionValueWithObject:nil context:NULL];
    
    NSPredicate *superPredicate = [NSPredicate predicateWithFormat:@"ALL labels.name != %@", labelName];
    [super setPredicate:superPredicate];
}

- (double)matchForPredicate:(NSPredicate *)predicate {
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c0 = (id)predicate;
        NSExpression *lhs = c0.leftExpression;
        NSExpression *rhs = c0.rightExpression;
        
        if (c0.predicateOperatorType != NSEqualToPredicateOperatorType) {
            return 0.0;
        }
        
        if (rhs.expressionType != NSConstantValueExpressionType
            || ![rhs.constantValue isEqual:@0])
        {
            return 0.0;
        }
        
        if (lhs.expressionType != NSFunctionExpressionType
            || ![lhs.function isEqualToString:@"count:"]) {
            return 0.0;
        }
        
        NSExpression *subq = [lhs.arguments firstObject];
        
        if (subq.expressionType == NSSubqueryExpressionType
            && [subq.collection expressionType] == NSKeyPathExpressionType
            && [[subq.collection keyPath] isEqualToString:@"labels"])
        {
            return 1.0;
        }
    }
    return 0.0;
}

@end

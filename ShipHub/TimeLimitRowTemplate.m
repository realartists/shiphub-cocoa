//
//  TimeLimitRowTemplate.m
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "TimeLimitRowTemplate.h"

@implementation TimeLimitRowTemplate {
    NSTextField *_unitsLabel;
}

- (id)initWithLeftExpressions:(NSArray *)leftExpressions {
    return [super initWithLeftExpressions:leftExpressions rightExpressionAttributeType:NSDoubleAttributeType modifier:NSDirectPredicateModifier operators:@[@(NSLessThanPredicateOperatorType), @(NSGreaterThanPredicateOperatorType)] options:0];
}

- (NSTextField *)unitsLabel {
    if (!_unitsLabel) {
        _unitsLabel = [[NSTextField alloc] initWithFrame:CGRectZero];
        _unitsLabel.editable = NO;
        _unitsLabel.selectable = NO;
        _unitsLabel.bordered = NO;
        _unitsLabel.drawsBackground = NO;
        _unitsLabel.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
        _unitsLabel.stringValue = NSLocalizedString(@"Days Ago", nil);
        [_unitsLabel sizeToFit];
    }
    return _unitsLabel;
}

- (NSArray *)templateViews {
    NSMutableArray *a = [[super templateViews] mutableCopy];
    [a addObject:[self unitsLabel]];
    return a;
}

- (NSPredicate *)predicateWithSubpredicates:(NSArray *)subpredicates {
    NSPredicate * p = [super predicateWithSubpredicates:subpredicates];
    if ([p isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate * comparison = (NSComparisonPredicate *)p;
        
        NSExpression *left = [comparison leftExpression];
        NSString *keyPath = [left keyPath];
        NSExpression * right = [comparison rightExpression];
        NSNumber * value = [right constantValue];
        
        NSPredicateOperatorType op = [comparison predicateOperatorType];
        
#define USE_DATEDIFF 1
        
#if USE_DATEDIFF
        if (op == NSLessThanPredicateOperatorType) {
            p = [NSPredicate predicateWithFormat:@"%K > FUNCTION(now(), 'dateByAddingDays:', -%@)", keyPath, value];
        } else {
            p = [NSPredicate predicateWithFormat:@"%K < FUNCTION(now(), 'dateByAddingDays:', -%@)", keyPath, value];
        }
#else
        if (op == NSLessThanPredicateOperatorType) {
            p = [NSPredicate predicateWithFormat:@"%K > CAST((CAST(now(), 'NSNumber') - (%@ * 86400.0)), 'NSDate')", keyPath, value];
        } else {
            p = [NSPredicate predicateWithFormat:@"%K < CAST((CAST(now(), 'NSNumber') - (%@ * 86400.0)), 'NSDate')", keyPath, value];
        }
#endif
    }
    return p;
}

- (void)setPredicate:(NSPredicate *)newPredicate {
    if ([newPredicate isKindOfClass:[NSComparisonPredicate class]]) {
        
        NSComparisonPredicate * comparison = (NSComparisonPredicate *)newPredicate;
        
        NSExpression *left = [comparison leftExpression];
        NSExpression *right = [comparison rightExpression];
        
        NSString *keyPath = [left keyPath];
        NSString *rightStr = [right description];
        
        if ([rightStr containsString:@"dateByAddingDays:"]) {
            NSRegularExpression *expr = [NSRegularExpression regularExpressionWithPattern:@".*FUNCTION\\(now\\(\\)\\s*,\\s*.dateByAddingDays:.\\s*,\\s*(\\-?\\d+).*" options:0 error:NULL];
            NSTextCheckingResult *match = [expr firstMatchInString:rightStr options:0 range:NSMakeRange(0, [rightStr length])];
            if (match) {
                NSRange range = [match rangeAtIndex:1];
                NSString *daysStr = [rightStr substringWithRange:range];
                double days = [daysStr doubleValue];
                if (days < 0) {
                    days = -days;
                }
                
                NSPredicateOperatorType op = [comparison predicateOperatorType];
                
                if (op == NSLessThanPredicateOperatorType) {
                    newPredicate = [NSPredicate predicateWithFormat:@"%K > %f", keyPath, days];
                } else {
                    newPredicate = [NSPredicate predicateWithFormat:@"%K < %f", keyPath, days];
                }
            }
        } else {
            NSRegularExpression *expr = [NSRegularExpression regularExpressionWithPattern:@".*\\(([\\d\\.]+)\\s*\\*\\s*86400(.0)?\\).*" options:0 error:NULL];
            NSTextCheckingResult *match = [expr firstMatchInString:rightStr options:0 range:NSMakeRange(0, [rightStr length])];
            if (match) {
                NSRange range = [match rangeAtIndex:1];
                NSString *daysStr = [rightStr substringWithRange:range];
                NSTimeInterval days = [daysStr doubleValue];
                
                NSPredicateOperatorType op = [comparison predicateOperatorType];
                
                if (op == NSLessThanPredicateOperatorType) {
                    newPredicate = [NSPredicate predicateWithFormat:@"%K > %f", keyPath, days];
                } else {
                    newPredicate = [NSPredicate predicateWithFormat:@"%K < %f", keyPath, days];
                }
            }
        }
    }
    
    [super setPredicate:newPredicate];
}

- (double)matchForPredicate:(NSPredicate *)predicate {
    if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *comparison = (NSComparisonPredicate *)predicate;
        
        NSExpression *left = [comparison leftExpression];
        
        if (left.expressionType != NSKeyPathExpressionType) {
            return 0.0;
        }
        
        NSString *keyPath = [left keyPath];
        
        for (NSExpression *lxpr in self.leftExpressions) {
            if ([[lxpr keyPath] isEqualToString:keyPath]) {
                return 1.0;
            }
        }
    }
    return 0.0;
}

@end

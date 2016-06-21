//
//  NSPredicate+Extras.h
//  Ship
//
//  Created by James Howard on 7/24/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSPredicate (Folding)

- (NSPredicate *)predicateByFoldingExpressions;

@end

@interface NSExpression (Folding)

- (NSExpression *)foldedExpression;

@end

typedef NSPredicate *(^PredicateRewriter)(NSPredicate *original);

@interface NSPredicate (Walking)

// Walk the predicate's syntax tree, visiting each node.
// For each node that is an NSExpression, run the predicate on it.
// If any expression in the tree matches, return YES. Otherwise, return NO.
- (BOOL)syntaxTreeContainsExpressionsMatchingPredicate:(NSPredicate *)predicate;

// Walks predicates recursively and rewrites them according to rewriter.
// Does not walk into expressions (so predicates that are part of an expression such
// as a subquery expression are not visited).
- (NSPredicate *)predicateByRewriting:(PredicateRewriter)rewriter;

// Return all nested predicates matching predicate
- (NSArray *)predicatesMatchingPredicate:(NSPredicate *)predicate;

// A predicate that matches other predicates which are comparison predicates with
// keyPath being on one side of the predicate
+ (NSPredicate *)predicateMatchingComparisonPredicateWithKeyPath:(NSString *)keyPath;

// Walk from root and if self is found anywhere in root, return the NSCompoundPredicate
// that contains self (if it exists).
- (NSCompoundPredicate *)parentPredicateInTree:(NSPredicate *)root;

@end

@interface NSExpression (Walking)

// Walk the predicate's syntax tree, visiting each node.
// For each node that is an NSExpression, run the predicate on it.
// If any expression in the tree matches, return YES. Otherwise, return NO.
- (BOOL)syntaxTreeContainsExpressionsMatchingPredicate:(NSPredicate *)predicate;

@end
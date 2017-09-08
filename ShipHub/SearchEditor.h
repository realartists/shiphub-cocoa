//
//  SearchEditor.h
//  Ship
//
//  Created by James Howard on 7/23/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SearchEditor : NSPredicateEditor

- (void)reset;

- (void)assignPredicate:(NSPredicate *)predicate;

- (void)addCompoundPredicate;

@end

//
//  QueryOptimizer.h
//  ShipHub
//
//  Created by James Howard on 9/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QueryOptimizer : NSObject

+ (NSPredicate *)optimizeIssuesPredicate:(NSPredicate *)predicate;

@end

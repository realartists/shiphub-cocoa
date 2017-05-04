//
//  PRMergeStrategy.h
//  ShipHub
//
//  Created by James Howard on 5/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PRMergeStrategy) {
    PRMergeStrategyMerge = 0,
    PRMergeStrategySquash,
    PRMergeStrategyRebase
};

//
//  BulkModifyController.m
//  ShipHub
//
//  Created by James Howard on 7/27/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "BulkModifyController.h"

@interface BulkModifyController ()

@end

@implementation BulkModifyController

- (id)initWithIssues:(NSArray<Issue *> *)issues {
    if (self = [super init]) {
        _issues = [issues copy];
    }
    return self;
}

@end

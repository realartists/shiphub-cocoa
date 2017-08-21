//
//  AssigneeNotContainsTemplate.h
//  ShipHub
//
//  Created by James Howard on 1/27/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "UserRowTemplate.h"

@interface ToManyUserNotContainsTemplate : UserRowTemplate

- (id)initWithLoginKeyPath:(NSString *)loginKeyPath;

@property (readonly) NSString *loginKeyPath;

@end

//
//  StateRowTemplate.m
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "StateRowTemplate.h"

@implementation StateRowTemplate

- (id)init {
    self = [super initWithMetadataType:@"state"];
    return self;
}

- (NSArray *)popUpItems {
    return @[@"open", @"closed"];
}

@end

//
//  MetadataItem.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "MetadataItem.h"

@implementation MetadataItem

- (instancetype)initWithLocalItem:(id)localItem {
    if (self = [super init]) {
        _identifier = [localItem valueForKey:@"identifier"];
    }
    return self;
}

@end

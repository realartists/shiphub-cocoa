//
//  MetadataItem.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "MetadataItem.h"

@implementation MetadataItem

#if TARGET_SHIP
- (instancetype)initWithLocalItem:(id)localItem {
    if (self = [super init]) {
        _identifier = [localItem valueForKey:@"identifier"];
    }
    return self;
}
#endif

- (instancetype)initWithDictionary:(NSDictionary *)d {
    if (self = [super init]) {
        _identifier = d[@"id"];
    }
    return self;
}

@end

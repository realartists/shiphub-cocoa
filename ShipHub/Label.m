//
//  Label.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Label.h"

#import "Extras.h"
#import "LocalLabel.h"

@implementation Label

#if TARGET_SHIP
- (instancetype)initWithLocalItem:(id)localItem {
    LocalLabel *ll = localItem;
    if (self = [super init]) {
        _name = ll.name;
#if TARGET_OS_IOS
        _color = [UIColor colorWithHexString:ll.color];
#else
        _color = [NSColor colorWithHexString:ll.color];
#endif
    }
    return self;
}
#endif

- (instancetype)initWithDictionary:(NSDictionary *)d {
    if (self = [super initWithDictionary:d]) {
        _name = d[@"name"];
#if TARGET_OS_IOS
        _color = [UIColor colorWithHexString:d[@"color"]];
#else
        _color = [NSColor colorWithHexString:d[@"color"]];
#endif
    }
    return self;
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@ %p> %@", NSStringFromClass([self class]), self, _name];
}

- (NSString *)description {
    return _name;
}

@end

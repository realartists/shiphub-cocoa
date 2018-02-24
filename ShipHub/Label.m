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
#import "GHEmoji.h"

@implementation Label

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

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@ %p> %@", NSStringFromClass([self class]), self, _name];
}

- (NSString *)description {
    return _name;
}

- (NSAttributedString *)emojifiedName {
    return [_name githubEmojify];
}

@end

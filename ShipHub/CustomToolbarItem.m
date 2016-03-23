//
//  CustomToolbarItem.m
//  Ship
//
//  Created by James Howard on 6/1/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "CustomToolbarItem.h"

@interface NSToolbarItem (FFS) <NSCoding>
@end

@implementation CustomToolbarItem

- (void)configureView { }

- (instancetype)initWithItemIdentifier:(NSString *)itemIdentifier {
    if (self = [super initWithItemIdentifier:itemIdentifier]) {
        [self configureView];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    return [[[self class] alloc] initWithItemIdentifier:[self itemIdentifier]];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self configureView];
    }
    return self;
}

@end

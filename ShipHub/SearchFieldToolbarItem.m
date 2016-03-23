//
//  SearchFieldToolbarItem.m
//  Ship
//
//  Created by James Howard on 6/1/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SearchFieldToolbarItem.h"
#import "SearchField.h"

@implementation SearchFieldToolbarItem

- (void)configureView {
    _searchField = [[SearchField alloc] initWithFrame:CGRectMake(0, 0, 200.0, 28.0)];
    _searchField.font = [NSFont systemFontOfSize:13.0];
    _searchField.autoresizingMask = NSViewWidthSizable;
    self.view = _searchField;
    self.minSize = CGSizeMake(50.0, 28.0);
    self.maxSize = CGSizeMake(10000.0, 28.0);
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    _searchField.animator.hidden = !enabled;
}

@end

//
//  SearchFieldToolbarItem.h
//  Ship
//
//  Created by James Howard on 6/1/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CustomToolbarItem.h"

@interface SearchFieldToolbarItem : CustomToolbarItem

@property (readonly) NSSearchField *searchField;

@end

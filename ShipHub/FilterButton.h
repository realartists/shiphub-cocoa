//
//  FilterButton.h
//  ShipHub
//
//  Created by James Howard on 6/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FilterButton : NSPopUpButton

@property (nonatomic, getter=isFilterEnabled) BOOL filterEnabled;

@end

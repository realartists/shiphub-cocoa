//
//  ButtonToolbarItem.h
//  Ship
//
//  Created by James Howard on 6/23/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CustomToolbarItem.h"

@interface ButtonToolbarItem : CustomToolbarItem

@property (nonatomic, strong) NSImage *buttonImage;
@property (nonatomic, assign) NSSegmentSwitchTracking trackingMode;

@property (nonatomic, getter=isOn) BOOL on;

@property (nonatomic) BOOL grayWhenDisabled;

@end

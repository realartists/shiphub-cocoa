//
//  ImagePopUpButton.h
//  Ship
//
//  Created by James Howard on 12/16/15.
//  Copyright © 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

IB_DESIGNABLE @interface ImagePopUpButton : NSPopUpButton

@property (nonatomic, strong) IBInspectable NSImage *backgroundImage;

@end

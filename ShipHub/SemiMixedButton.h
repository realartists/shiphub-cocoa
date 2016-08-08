//
//  SemiMixedButton.h
//  ShipHub
//
//  Created by James Howard on 8/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* 
    An NSButton that can programmatically have the Mixed state
    set on it, but that toggles between Off and On states only
    when it is clicked
*/
@interface SemiMixedButton : NSButton

@property NSInteger nextStateAfterMixed; // default is NSOffState

@end

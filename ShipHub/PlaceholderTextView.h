//
//  PlaceholderTextView.h
//  ShipHub
//
//  Created by James Howard on 3/2/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

IB_DESIGNABLE
@interface PlaceholderTextView : NSTextView

@property (nonatomic, copy) IBInspectable NSString *placeholderString;

@end


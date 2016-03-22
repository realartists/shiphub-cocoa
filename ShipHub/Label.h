//
//  Label.h
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MetadataItem.h"

@interface Label : MetadataItem

@property (readonly) NSString *name;
@property (readonly) NSString *colorString;

#if TARGET_OS_IOS
@property (readonly) UIColor *color;
#else
@property (readonly) NSColor *color;
#endif

@end

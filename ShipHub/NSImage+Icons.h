//
//  NSImage+Icons.h
//  Ship
//
//  Created by James Howard on 8/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (Icons)

+ (NSImage *)sidebarIcon;

+ (NSImage *)advancedSearchIcon;

+ (NSImage *)partitionsIcon;
+ (NSImage *)searchResultsIcon;
+ (NSImage *)threePaneIcon;
+ (NSImage *)chartingIcon;

+ (NSImage *)watchStarOff;
+ (NSImage *)watchStarOffHover;
+ (NSImage *)watchStarOn;
+ (NSImage *)watchStarOnHover;

+ (NSImage *)overviewIconNamed:(NSString *)name;

@end

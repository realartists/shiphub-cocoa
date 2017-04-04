//
//  TrackingProgressSheet.h
//  ShipHub
//
//  Created by James Howard on 4/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TrackingProgressSheet : NSWindowController

@property (nonatomic) NSProgress *progress;

- (void)beginSheetInWindow:(NSWindow *)window;
- (void)endSheet;

@end

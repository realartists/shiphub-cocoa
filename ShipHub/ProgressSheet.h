//
//  ProblemProgressController.h
//  Ship
//
//  Created by James Howard on 5/21/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ProgressSheet : NSWindowController

@property (nonatomic, copy) NSString *message;

- (void)beginSheetInWindow:(NSWindow *)window;
- (void)endSheet;

@end

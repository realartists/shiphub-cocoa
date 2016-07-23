//
//  SaveSearchController.h
//  Ship
//
//  Created by James Howard on 7/29/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SaveSearchController : NSWindowController

@property (nonatomic, copy) NSString *title;

- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(void (^)(NSInteger result))handler;

@end

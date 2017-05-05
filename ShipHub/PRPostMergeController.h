//
//  PRPostMergeController.h
//  ShipHub
//
//  Created by James Howard on 5/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Issue;

@interface PRPostMergeController : NSWindowController

@property (nonatomic, strong) Issue *issue;

- (void)beginSheetModalForWindow:(NSWindow *)parentWindow completion:(dispatch_block_t)completion;

@end

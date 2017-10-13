//
//  NSViewController+PresentSaveError.h
//  Ship
//
//  Created by James Howard on 10/13/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSViewController (PresentSaveError)

- (void)presentSaveError:(NSError *)error withRetry:(dispatch_block_t)retry fail:(dispatch_block_t)fail;

@end

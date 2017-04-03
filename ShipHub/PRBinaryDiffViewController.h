//
//  PRBinaryDiffViewController.h
//  ShipHub
//
//  Created by James Howard on 4/3/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GitDiffFile;

@interface PRBinaryDiffViewController : NSViewController

- (void)setFile:(GitDiffFile *)file oldData:(NSData *)oldData newData:(NSData *)newData;

@property (nonatomic, readonly) GitDiffFile *file;

@end

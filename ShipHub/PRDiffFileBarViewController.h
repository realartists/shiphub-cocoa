//
//  PRDiffFileBarViewController.h
//  ShipHub
//
//  Created by James Howard on 3/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GitDiffFile;

@interface PRDiffFileBarViewController : NSViewController

@property (nonatomic) GitDiffFile *file;

@end

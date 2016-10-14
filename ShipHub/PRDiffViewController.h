//
//  PRDiffViewController.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IssueWebController.h"

@class GitDiffFile;

@interface PRDiffViewController : IssueWebController

@property (nonatomic, strong) GitDiffFile *diffFile;

@end

//
//  PRDiffViewController.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IssueWeb2Controller.h"
#import "DiffViewMode.h"

@class GitDiffFile;

@interface PRDiffViewController : IssueWeb2Controller

@property (nonatomic, strong) GitDiffFile *diffFile;

@property (nonatomic, assign) DiffViewMode mode;

@end

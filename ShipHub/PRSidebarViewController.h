//
//  PRSidebarViewController.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PullRequest;
@class GitDiff;
@class GitDiffFile;
@class PRComment;
@protocol PRSidebarViewControllerDelegate;

@interface PRSidebarViewController : NSViewController

@property (nonatomic, strong) PullRequest *pr;

@property (weak) id<PRSidebarViewControllerDelegate> delegate;

@property (nonatomic) GitDiff *activeDiff;
@property (nonatomic) GitDiffFile *selectedFile;
@property (nonatomic) NSArray<PRComment *> *allComments;

- (BOOL)canGoNextFile;
- (BOOL)canGoPreviousFile;

- (IBAction)nextFile:(id)sender;
- (IBAction)previousFile:(id)sender;

@end

@protocol PRSidebarViewControllerDelegate <NSObject>

- (void)prSidebar:(PRSidebarViewController *)sidebar didSelectGitDiffFile:(GitDiffFile *)file;

@end



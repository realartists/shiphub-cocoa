//
//  PRSidebarViewController.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PullRequest;
@class GitCommit;
@class GitDiff;
@class GitDiffFile;
@class PRComment;
@protocol PRSidebarViewControllerDelegate;

@interface PRSidebarViewController : NSViewController

@property (nonatomic, strong) PullRequest *pr;

@property (weak) id<PRSidebarViewControllerDelegate> delegate;

@property (nonatomic) GitDiff *activeDiff;
@property (nonatomic) GitCommit *activeCommit; // nil unless activeDiff is the diff of a specific commit to its parent
@property (nonatomic) GitDiffFile *selectedFile;
@property (nonatomic) NSArray<PRComment *> *allComments;

- (BOOL)canGoNextFile;
- (BOOL)canGoPreviousFile;

- (IBAction)nextFile:(id)sender;
- (IBAction)previousFile:(id)sender;

- (IBAction)nextCommentedFile:(id)sender;
- (IBAction)previousCommentedFile:(id)sender;

- (BOOL)selectFileAtPath:(NSString *)path;

- (IBAction)filterInNavigator:(id)sender;

@end

@protocol PRSidebarViewControllerDelegate <NSObject>

- (void)prSidebar:(PRSidebarViewController *)sidebar didSelectGitDiffFile:(GitDiffFile *)file;

@end



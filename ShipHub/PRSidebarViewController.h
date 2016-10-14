//
//  PRSidebarViewController.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PullRequest;
@class GitDiffFile;
@protocol PRSidebarViewControllerDelegate;

@interface PRSidebarViewController : NSViewController

@property (nonatomic, strong) PullRequest *pr;

@property (weak) id<PRSidebarViewControllerDelegate> delegate;

@end

@protocol PRSidebarViewControllerDelegate <NSObject>

- (void)prSidebar:(PRSidebarViewController *)sidebar didSelectGitDiffFile:(GitDiffFile *)file;

@end



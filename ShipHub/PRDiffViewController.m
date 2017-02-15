//
//  PRDiffViewController.m
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRDiffViewController.h"
#import "IssueWeb2ControllerInternal.h"

#import "PullRequest.h"
#import "Issue.h"
#import "PRComment.h"
#import "GitDiff.h"
#import "JSON.h"

#import <WebKit/WebKit.h>

@interface PRDiffViewController () {
    NSInteger _loadCount;
}


@end

@implementation PRDiffViewController

- (NSInteger)webpackDevServerPort {
    return 8081;
}

- (NSString *)webResourcePath {
    return @"DiffWeb";
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setPR:(PullRequest *)pr diffFile:(GitDiffFile *)diffFile comments:(NSArray<PRComment *> *)comments {
    _pr = pr;
    _diffFile = diffFile;
    _comments = comments;
    NSInteger count = ++_loadCount;
    [diffFile loadTextContents:^(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error) {
        if (_loadCount != count) return;
        
        NSString *js = [NSString stringWithFormat:@"window.updateDiff(%@, %@, %@, %@, %@, %@);", [JSON stringifyObject:diffFile.name], [JSON stringifyObject:oldFile], [JSON stringifyObject:newFile], [JSON stringifyObject:patch], [JSON stringifyObject:pr.issue.fullIdentifier], [JSON stringifyObject:comments]];
        [self evaluateJavaScript:js];
    }];
}

- (void)reconfigureForReload {
    [self setPR:_pr diffFile:_diffFile comments:_comments];
    [self setMode:_mode];
}

- (void)setMode:(DiffViewMode)mode {
    _mode = mode;
    const char *modeStr = NULL;
    switch (mode) {
        case DiffViewModeUnified: modeStr = "unified"; break;
        case DiffViewModeSplit: modeStr = "split"; break;
    }
    [self evaluateJavaScript:[NSString stringWithFormat:@"window.setDiffMode('%s');", modeStr]];
}

@end

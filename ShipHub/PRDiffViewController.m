//
//  PRDiffViewController.m
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRDiffViewController.h"
#import "IssueWebControllerInternal.h"

#import "GitDiff.h"
#import "JSON.h"

#import <WebKit/WebKit.h>

@interface PRDiffViewController ()


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
    self.web.drawsBackground = YES;
    self.web.wantsLayer = YES;
    self.web.mainFrame.frameView.documentView.enclosingScrollView.hasVerticalScroller = NO;
}

- (void)setDiffFile:(GitDiffFile *)diffFile {
    _diffFile = diffFile;
    [diffFile loadTextContents:^(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error) {
        NSString *js = [NSString stringWithFormat:@"window.updateDiff(%@, %@, %@);", [JSON stringifyObject:oldFile], [JSON stringifyObject:newFile], [JSON stringifyObject:patch]];
        [self evaluateJavaScript:js];
    }];
}

- (void)reconfigureForReload {
    [self setDiffFile:_diffFile];
}

@end

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

@interface NSObject (BadManTings)

- (void)setAlwaysHideVerticalScroller:(BOOL)flag;

@end

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
    self.web.drawsBackground = YES;
    self.web.wantsLayer = YES;
    DebugLog(@"%@", self.web.mainFrame.frameView.documentView.enclosingScrollView);
    //[self.web.mainFrame.frameView.documentView.enclosingScrollView setAlwaysHideVerticalScroller:YES];
}

- (void)setDiffFile:(GitDiffFile *)diffFile {
    _diffFile = diffFile;
    NSInteger count = ++_loadCount;
    [diffFile loadTextContents:^(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error) {
        if (_loadCount != count) return;
        
        NSString *js = [NSString stringWithFormat:@"window.updateDiff(%@, %@, %@, %@);", [JSON stringifyObject:diffFile.name], [JSON stringifyObject:oldFile], [JSON stringifyObject:newFile], [JSON stringifyObject:patch]];
        [self evaluateJavaScript:js];
    }];
}

- (void)reconfigureForReload {
    [self setDiffFile:_diffFile];
}

@end

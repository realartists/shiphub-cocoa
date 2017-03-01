//
//  PRDiffViewController.m
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRDiffViewController.h"
#import "IssueWeb2ControllerInternal.h"

#import "DataStore.h"
#import "PullRequest.h"
#import "Issue.h"
#import "PRComment.h"
#import "GitDiff.h"
#import "JSON.h"
#import "Account.h"
#import "WebKitExtras.h"

@interface PRDiffViewController () {
    NSInteger _loadCount;
}

@end

@implementation PRDiffViewController

- (NSString *)webResourcePath {
    return @"IssueWeb";
}

- (NSString *)webHtmlFilename {
    return @"diff.html";
}

- (void)registerJavaScriptAPI:(WKUserContentController *)cc {
    [super registerJavaScriptAPI:cc];
    
    __weak __typeof(self) weakSelf = self;
    
    // TODO:
    //  documentEditedHelper
    //  queue comment handler
    //  post comment immediately
    
    [cc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf queueReviewComment:msg.body];
    } name:@"queueReviewComment"];
}

- (void)queueReviewComment:(NSDictionary *)msg {
    PendingPRComment *pending = [[PendingPRComment alloc] initWithDictionary:msg metadataStore:[[DataStore activeStore] metadataStore]];
    _inReview = YES;
    [self.delegate diffViewController:self queueReviewComment:pending];
}

- (void)setPR:(PullRequest *)pr diffFile:(GitDiffFile *)diffFile diff:(GitDiff *)diff comments:(NSArray<PRComment *> *)comments inReview:(BOOL)inReview
{
    _pr = pr;
    _diffFile = diffFile;
    _diff = diff;
    _comments = [comments mutableCopy];
    _inReview = inReview;
    NSInteger count = ++_loadCount;
    [diffFile loadTextContents:^(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error) {
        if (_loadCount != count) return;
        
        NSDictionary *state =
        @{ @"filename": diffFile.name,
           @"path": diffFile.path,
           @"leftText": oldFile ?: @"",
           @"rightText": newFile ?: @"",
           @"diff": patch ?: @"",
           @"comments": [JSON serializeObject:comments withNameTransformer:[JSON underbarsAndIDNameTransformer]],
           @"issueIdentifier": _pr.issue.fullIdentifier,
           @"inReview": @(inReview),
           @"baseSha": diff.baseRev,
           @"headSha": diff.headRev,
           @"me" : [JSON serializeObject:[Account me] withNameTransformer:[JSON underbarsAndIDNameTransformer]]
        };
        
        NSString *js = [NSString stringWithFormat:@"window.updateDiff(%@);", [JSON stringifyObject:state]];
        [self evaluateJavaScript:js];
    }];
}

- (void)reconfigureForReload {
    [self setPR:_pr diffFile:_diffFile diff:_diff comments:_comments inReview:_inReview];
    [self setMode:_mode];
}

- (void)setComments:(NSArray<PRComment *> *)comments {
    _comments = comments;
    NSString *js = [NSString stringWithFormat:@"window.updateComments(%@);", [JSON stringifyObject:comments withNameTransformer:[JSON underbarsAndIDNameTransformer]]];
    [self evaluateJavaScript:js];
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

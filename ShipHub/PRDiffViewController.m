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
    
    [cc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf addSingleComment:msg.body];
    } name:@"addSingleComment"];
    
    [cc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf editComment:msg.body];
    } name:@"editComment"];
    
    [cc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf deleteComment:msg.body];
    } name:@"deleteComment"];
    
    [cc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf scrollContinuation:msg.body];
    } name:@"scrollContinuation"];
}

- (void)scrollContinuation:(NSDictionary *)msg {
    [self.delegate diffViewController:self continueNavigation:msg];
}

- (void)queueReviewComment:(NSDictionary *)msg {
    PendingPRComment *pending = [[PendingPRComment alloc] initWithDictionary:msg metadataStore:[[DataStore activeStore] metadataStore]];
    _inReview = YES;
    [self.delegate diffViewController:self queueReviewComment:pending];
}

- (void)addSingleComment:(NSDictionary *)msg {
    PendingPRComment *pending = [[PendingPRComment alloc] initWithDictionary:msg metadataStore:[[DataStore activeStore] metadataStore]];
    [self.delegate diffViewController:self addReviewComment:pending];
}

- (void)editComment:(NSDictionary *)msg {
    PRComment *comment = nil;
    Class commentClass = [PRComment class];
    if (msg[@"pending_id"]) {
        commentClass = [PendingPRComment class];
    }
    comment = [[commentClass alloc] initWithDictionary:msg metadataStore:[[DataStore activeStore] metadataStore]];
    [self.delegate diffViewController:self editReviewComment:comment];
}

- (void)deleteComment:(NSDictionary *)msg {
    PRComment *comment = nil;
    Class commentClass = [PRComment class];
    if (msg[@"pending_id"]) {
        commentClass = [PendingPRComment class];
    }
    comment = [[commentClass alloc] initWithDictionary:msg metadataStore:[[DataStore activeStore] metadataStore]];
    [self.delegate diffViewController:self deleteReviewComment:comment];
}

- (void)setPR:(PullRequest *)pr diffFile:(GitDiffFile *)diffFile diff:(GitDiff *)diff comments:(NSArray<PRComment *> *)comments inReview:(BOOL)inReview scrollInfo:(NSDictionary *)scrollInfo
{
    NSParameterAssert(comments);
    
    _pr = pr;
    _diffFile = diffFile;
    _diff = diff;
    _comments = [comments copy];
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
        
        if (scrollInfo) {
            [self navigate:scrollInfo];
        }
    }];
}

- (void)reconfigureForReload {
    [self setPR:_pr diffFile:_diffFile diff:_diff comments:_comments inReview:_inReview scrollInfo:nil];
    [self setMode:_mode];
}

- (void)setComments:(NSArray<PRComment *> *)comments {
    NSParameterAssert(comments);
    
    _comments = [comments copy];
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

- (void)scrollToComment:(PRComment *)comment {
    NSString *js;
    if ([comment isKindOfClass:[PendingPRComment class]]) {
        js = [NSString stringWithFormat:@"window.scrollToCommentId(%@);", [JSON stringifyObject:((PendingPRComment *)comment).pendingId]];
    } else {
        js = [NSString stringWithFormat:@"window.scrollToCommentId(%@);", [JSON stringifyObject:comment.identifier]];
    }
    
    [self evaluateJavaScript:js];
}

- (void)navigate:(NSDictionary *)options {
    NSString *js = [NSString stringWithFormat:@"window.scrollTo(%@);", [JSON stringifyObject:options]];
    [self evaluateJavaScript:js];
}

@end

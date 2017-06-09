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
#import "MarkdownFormattingController.h"
#import "PRDiffFileBarViewController.h"
#import "PRBinaryDiffViewController.h"
#import "PRFindBarController.h"
#import "WebKitExtras.h"

@interface PRDiffViewController () <MarkdownFormattingControllerDelegate, PRFindBarControllerDelegate> {
    NSInteger _loadCount;
}

@property MarkdownFormattingController *markdownFormattingController;
@property PRFindBarController *findController;
@property PRDiffFileBarViewController *fileBarController;
@property PRBinaryDiffViewController *binaryController;

@end

@implementation PRDiffViewController

- (void)loadView {
    _markdownFormattingController = [MarkdownFormattingController new];
    _markdownFormattingController.delegate = self;
    _markdownFormattingController.requireFocusToValidateActions = YES;
    
    _markdownFormattingController.nextResponder = self.nextResponder;
    [super setNextResponder:_markdownFormattingController];
    
    _findController = [PRFindBarController new];
    _findController.viewContainer = self;
    _findController.delegate = self;
    
    [super loadView];
    
    _fileBarController = [PRDiffFileBarViewController new];
    [self.view addSubview:_fileBarController.view];
}

- (CGRect)webContentRect {
    CGRect b = self.view.bounds;
    b.size.height -= _fileBarController.view.frame.size.height;
    return b;
}

- (void)layoutSubviews {
    CGRect b = self.view.bounds;
    NSView *fbView = _fileBarController.view;
    _fileBarController.view.frame = CGRectMake(0,
                                               CGRectGetHeight(b) - fbView.frame.size.height,
                                               CGRectGetWidth(b),
                                               fbView.frame.size.height);
    _binaryController.view.frame = [self webContentRect];
    [super layoutSubviews];
}

- (void)setNextResponder:(NSResponder *)nextResponder {
    if (_markdownFormattingController) {
        _markdownFormattingController.nextResponder = nextResponder;
    } else {
        [super setNextResponder:nextResponder];
    }
}

- (NSTouchBar *)makeTouchBar {
    if (_markdownFormattingController.hasCommentFocus) {
        return _markdownFormattingController.markdownTouchBar;
    }
    
    return nil;
}

- (void)focus {
    [self.web.window makeFirstResponder:self.web];
}

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
    
    [_markdownFormattingController registerJavaScriptAPI:cc];
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

static BOOL differentiateWithoutColor() {
    return CFPreferencesGetAppBooleanValue(CFSTR("differentiateWithoutColor"), CFSTR("com.apple.universalaccess"), NULL);
}

- (void)setPR:(PullRequest *)pr diffFile:(GitDiffFile *)diffFile diff:(GitDiff *)diff comments:(NSArray<PRComment *> *)comments inReview:(BOOL)inReview scrollInfo:(NSDictionary *)scrollInfo
{
    NSParameterAssert(comments);
    
    _pr = pr;
    if (_diffFile != diffFile) {
        [_findController hide];
    }
    _diffFile = diffFile;
    _diff = diff;
    _comments = [comments copy];
    _inReview = inReview;
    _fileBarController.file = diffFile;
    
    BOOL needsDiffMapping = diff != pr.spanDiff;
    GitDiffFile *mappingFile = nil;
    
    if (needsDiffMapping) {
        GitDiff *spanDiff = pr.spanDiff;
        for (GitDiffFile *spanFile in spanDiff.allFiles) {
            if (spanFile.path && diffFile.path && [spanFile.path isEqualToString:diffFile.path]) {
                mappingFile = spanFile;
                break;
            } else if (spanFile.oldPath && diffFile.path && [spanFile.oldPath isEqualToString:diffFile.path]) {
                // file has been renamed since our currently viewed commit(s)
                mappingFile = spanFile;
                break;
            }
        }
    }
    
    NSInteger count = ++_loadCount;
    [diffFile loadContentsAsText:^(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error) {
        if (_loadCount != count) return;
        
        void (^complete)(id) = ^(id patchMapping) {
            [self showTextDiff];
            
            NSDictionary *state =
            @{ @"filename": diffFile.name,
               @"path": diffFile.path,
               @"leftText": oldFile ?: @"",
               @"rightText": newFile ?: @"",
               @"diff": patch ?: @"",
               @"diffIdxMapping": patchMapping ?: [NSNull null],
               @"comments": [JSON serializeObject:comments withNameTransformer:[JSON underbarsAndIDNameTransformer]],
               @"issueIdentifier": _pr.issue.fullIdentifier,
               @"inReview": @(inReview),
               @"baseSha": pr.spanDiff.baseRev,
               @"headSha": pr.spanDiff.headRev,
               @"colorblind" : @(differentiateWithoutColor()),
               @"me" : [JSON serializeObject:[Account me] withNameTransformer:[JSON underbarsAndIDNameTransformer]]
               };
            
            NSString *js = [NSString stringWithFormat:@"window.updateDiff(%@);", [JSON stringifyObject:state]];
            [self evaluateJavaScript:js];
            
            if (scrollInfo) {
                [self navigate:scrollInfo];
            }
        };
        
        if (needsDiffMapping) {
            [GitDiffFile computePatchMappingFromPatch:patch toPatchForFile:mappingFile completion:^(NSArray *mapping) {
                complete(mapping);
            }];
        } else {
            complete(nil);
        }
        
    } asBinary:^(NSData *oldFile, NSData *newFile, NSError *error) {
        if (_loadCount != count) return;
        
        [self showBinaryDiff];
        
        [_binaryController setFile:diffFile oldData:oldFile newData:newFile];
    }];
}

- (BOOL)isShowingBinaryDiff {
    return self.web.hidden;
}

- (void)showTextDiff {
    if (self.web.hidden) {
        self.web.hidden = NO;
        [_binaryController.view removeFromSuperview];
    }
}

- (void)showBinaryDiff {
    if (!_binaryController) {
        _binaryController = [PRBinaryDiffViewController new];
    }
    if (![_binaryController.view superview]) {
        self.web.hidden = YES;
        [self.view addSubview:_binaryController.view];
        [self layoutSubviews];
    }
}

- (void)reconfigureForReload {
    [self setPR:_pr diffFile:_diffFile diff:_diff comments:_comments inReview:_inReview scrollInfo:nil];
    [self setMode:_mode];
}

- (void)setComments:(NSArray<PRComment *> *)comments inReview:(BOOL)inReview {
    NSParameterAssert(comments);
    
    _comments = [comments copy];
    NSString *js = [NSString stringWithFormat:@"window.updateComments(%@, %s);", [JSON stringifyObject:comments withNameTransformer:[JSON underbarsAndIDNameTransformer]], inReview?"true":"false"];
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
    if ([self isShowingBinaryDiff]) {
        [self.delegate diffViewController:self continueNavigation:options];
    } else {
        NSString *js = [NSString stringWithFormat:@"window.scrollTo(%@);", [JSON stringifyObject:options]];
        [self evaluateJavaScript:js];
    }
}

#pragma mark - Text Finding

- (void)hideFindController {
    [_findController hide];
}

- (IBAction)performFindPanelAction:(id)sender {
    [_findController performFindAction:[sender tag]];
}

- (IBAction)performTextFinderAction:(nullable id)sender {
    [_findController performFindAction:[sender tag]];
}

- (void)findBarController:(PRFindBarController *)controller searchFor:(NSString *)str {
    NSString *js = [NSString stringWithFormat:@"window.search(%@)", [JSON stringifyObject:@{ @"str" : str }]];
    [self evaluateJavaScript:js];
}

- (void)findBarControllerScrollToSelection:(PRFindBarController *)controller {
    NSString *js = [NSString stringWithFormat:@"window.search(%@)", [JSON stringifyObject:@{ @"action" : @"scroll" }]];
    [self evaluateJavaScript:js];
}

- (void)findBarControllerGoNext:(PRFindBarController *)controller {
    NSString *js = [NSString stringWithFormat:@"window.search(%@)", [JSON stringifyObject:@{ @"action" : @"next" }]];
    [self evaluateJavaScript:js];
}

- (void)findBarControllerGoPrevious:(PRFindBarController *)controller {
    NSString *js = [NSString stringWithFormat:@"window.search(%@)", [JSON stringifyObject:@{ @"action" : @"previous" }]];
    [self evaluateJavaScript:js];
}

- (void)findBarController:(PRFindBarController *)controller selectedTextForFind:(void (^)(NSString *))handler
{
    NSString *js = [NSString stringWithFormat:@"window.search()"];
    if (self.didFinishLoading) {
        [self.web evaluateJavaScript:js completionHandler:^(id txt, NSError *error) {
            handler(txt);
        }];
    } else {
        handler(@"");
    }
}

@end

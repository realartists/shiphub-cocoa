//
//  IssueViewController.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueViewController.h"

#import "Issue.h"
#import "IssueIdentifier.h"

#import <WebKit/WebKit.h>

@interface IssueViewController () <WKNavigationDelegate> {
    BOOL _didFinishLoading;
    NSString *_javaScriptToRun;
}

@property WKWebView *web;

@end

@implementation IssueViewController

- (void)loadView {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKUserContentController *userContent = [WKUserContentController new];
    config.userContentController = userContent;

    _web = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 600, 600) configuration:config];
    _web.navigationDelegate = self;
    self.view = _web;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *indexPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"IssueWeb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:indexPath]];
    [_web loadRequest:request];
}

- (void)setIssue:(Issue *)issue {
    NSString *issueIdentifier = [issue fullIdentifier];
    NSString *js = [NSString stringWithFormat:@"updateIssue('%@', '%@', '%@')", [issueIdentifier issueRepoOwner], [issueIdentifier issueRepoName], [issueIdentifier issueNumber]];
    [self evaluateJavaScript:js];
    self.title = issue.title ?: NSLocalizedString(@"Untitled Issue", nil);
}

- (void)evaluateJavaScript:(NSString *)js {
    if (!_didFinishLoading) {
        _javaScriptToRun = js;
    } else {
        [_web evaluateJavaScript:js completionHandler:^(id o, NSError *e) {
            if (e) {
                ErrLog(@"%@", e);
            }
        }];
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    _didFinishLoading = YES;
    if (_javaScriptToRun) {
        [self evaluateJavaScript:_javaScriptToRun];
        _javaScriptToRun = nil;
    }
}

@end

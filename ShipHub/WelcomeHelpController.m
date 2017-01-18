//
//  WelcomeController.m
//  Ship
//
//  Created by James Howard on 1/18/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "WelcomeHelpController.h"

#import "ButtonToolbarItem.h"

#import <WebKit/WebKit.h>

@interface WelcomeHelpController () <WKNavigationDelegate> {
    BOOL _loaded;
    BOOL _needsShow;
    BOOL _needsReload;
}

@property IBOutlet WKWebView *web;

@property IBOutlet ButtonToolbarItem *back;
@property IBOutlet ButtonToolbarItem *forward;
@property IBOutlet ButtonToolbarItem *reload;

@end

@implementation WelcomeHelpController

- (NSString *)windowNibName {
    return @"WelcomeHelpController";
}

- (IBAction)loadThenShow:(id)sender {
    if (_loaded) {
        [self showWindow:nil];
    } else {
        _needsShow = YES;
        [self window];
        if (_needsReload) {
            [self sendRequest];
        }
        _needsShow = YES;
    }
}

- (void)sendRequest {
    _needsReload = NO;
    NSURL *URL = [NSURL URLWithString:@"https://www.realartists.com/docs/2.0/welcome.html"];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    [_web loadRequest:request];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self.window setTitleVisibility:NSWindowTitleHidden];
    
    _back.grayWhenDisabled = YES;
    _forward.grayWhenDisabled = YES;
    
    _back.buttonImage = [NSImage imageNamed:NSImageNameGoLeftTemplate];
    _forward.buttonImage = [NSImage imageNamed:NSImageNameGoRightTemplate];
    _reload.buttonImage = [NSImage imageNamed:NSImageNameRefreshTemplate];
    
    _web.navigationDelegate = self;
    [self sendRequest];
}

- (void)showWindow:(id)sender {
    if (_needsReload) {
        [self sendRequest];
    }
    [super showWindow:sender];
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
    _back.enabled = webView.canGoBack;
    _forward.enabled = webView.canGoForward;
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    _loaded = YES;
    if (_needsShow) {
        [self showWindow:nil];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WelcomeShown"];
    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    ErrLog("%@", error);
    _needsReload = YES;
    _loaded = NO;
}

- (IBAction)back:(id)sender {
    [_web goBack];
}

- (IBAction)forward:(id)sender {
    [_web goForward];
}

- (IBAction)reload:(id)sender {
    [_web reload];
}

@end

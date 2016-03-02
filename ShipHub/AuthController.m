//
//  AuthController.m
//  Ship
//
//  Created by James Howard on 6/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "AuthController.h"

#import "Auth.h"
#import "Extras.h"

#import <WebKit/WebKit.h>

@interface AuthWindow : NSWindow

@end

@interface AuthController () <NSWindowDelegate> {
    BOOL _registered;
}

@property IBOutlet NSView *container;

@property WKWebView *webView;

@end

@implementation AuthController

- (NSString *)windowNibName {
    return @"AuthController";
}

- (void)windowDidLoad {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKUserContentController *userContent = [WKUserContentController new];
    
    __weak __typeof(self) weakSelf = self;
    [userContent addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf start];
    } name:@"startOver"];
    
    [userContent addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        NSDictionary *body = msg.body;
        [weakSelf finishWithAccount:body[@"account"] token:body[@"token"]];
    } name:@"finish"];
    
    config.userContentController = userContent;
    
    _webView = [[WKWebView alloc] initWithFrame:self.window.contentView.bounds configuration:config];
    [self.window.contentView setContentView:_webView];
}

- (IBAction)showWindow:(id)sender {
    [self window];
    [self start];
}

- (void)start {
    [_webView loa]
}

- (void)finishWithAccount:(NSDictionary *)accountInfo token:(NSString *)token {
    AuthAccount *account = [[AuthAccount alloc] initWithDictionary:accountInfo];
    if (account) {
        Auth *auth = [Auth authWithAccount:account token:token];
        [self.delegate authController:self authenticated:auth];
    } else {
        ErrLog(@"Received invalid account data: %@", accountInfo);
        [self start];
    }
}

@end

@implementation AuthWindow

- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }

@end


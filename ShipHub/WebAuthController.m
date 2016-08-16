//
//  WebAuthController.m
//  ShipHub
//
//  Created by James Howard on 8/15/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "WebAuthController.h"

#import "ABTesting.h"
#import "Auth.h"
#import "AuthController.h"
#import "Extras.h"
#import "NavigationController.h"
#import "ButtonToolbarItem.h"
#import "OAuthController.h"
#import "Reachability.h"

#import <WebKit/WebKit.h>
#import <SecurityInterface/SFCertificatePanel.h>

@interface WebWindow : NSWindow

@property (nonatomic, getter=isSecure) BOOL secure;
@property (weak) id secureTarget;
@property (assign) SEL secureAction;

@end

@interface WebAuthController () <WKUIDelegate, WKNavigationDelegate>

@property AuthController *authController;

@property IBOutlet NSView *webContainer;
@property WKWebView *web;
@property IBOutlet ButtonToolbarItem *back;
@property IBOutlet ButtonToolbarItem *forward;
@property IBOutlet ButtonToolbarItem *reload;
@property IBOutlet NSProgressIndicator *progress;

@property IBOutlet NSButton *secureButton;

@property (getter=isComplete) BOOL complete;
@property BOOL failed;

@end

@implementation WebAuthController

- (id)initWithAuthController:(AuthController *)authController {
    if (self = [super initWithWindowNibName:@"WebAuthController"]) {
        _authController = authController;
    }
    return self;
}

- (void)dealloc {
    _web.UIDelegate = nil;
    _web.navigationDelegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad {
    WebWindow *ww = (id)self.window;
    ww.secure = NO;
    ww.secureTarget = self;
    ww.secureAction = @selector(showCerts:);
    
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    _web = [[WKWebView alloc] initWithFrame:_webContainer.bounds configuration:config];
    _web.UIDelegate = self;
    _web.navigationDelegate = self;
    
    [_webContainer setContentView:_web];
    
    _back.grayWhenDisabled = YES;
    _forward.grayWhenDisabled = YES;
    _reload.grayWhenDisabled = YES;
    
    _back.enabled = NO;
    _forward.enabled = NO;
    
    _back.buttonImage = [NSImage imageNamed:NSImageNameGoLeftTemplate];
    _forward.buttonImage = [NSImage imageNamed:NSImageNameGoRightTemplate];
    _reload.buttonImage = [NSImage imageNamed:NSImageNameRefreshTemplate];
    
    _progress.hidden = NO;
    [_progress startAnimation:nil];
    
    [_web loadRequest:[self startRequest]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:ReachabilityDidChangeNotification object:[Reachability sharedInstance]];
}

- (NSString *)clientID {
    return @"da1cde7cfd134d837ae6";
}

- (NSString *)scopes {
    return @"user:email,repo,admin:repo_hook,read:org,admin:org_hook";
}

- (NSURL *)startURL {
    NSURLComponents *comps = [NSURLComponents componentsWithString:@"https://github.com/login/oauth/authorize"];
    NSDictionary *query = @{ @"client_id" : [self clientID],
                             @"scope" : [self scopes] };
    [comps setQueryItemsFromDictionary:query];
    return comps.URL;
}

- (NSURLRequest *)startRequest {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self startURL]];
    //request.HTTPShouldHandleCookies = NO;
    return request;
}

- (void)processAuthCode:(NSString *)authCode {
    _complete = YES;
    
    OAuthController *oauth = [[OAuthController alloc] initWithAuthCode:authCode];
    oauth.shipHost = self.shipHost;
    [_authController continueWithViewController:oauth];
    [self close];
}

- (BOOL)handleCodeURL:(NSURL *)URL {
    NSURLComponents *comps = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    if ([@[@"realartists.com", @"beta.realartists.com"] containsObject:comps.host]) {
        if ([[comps path] isEqualToString:@"/signup/index.html"]) {
            NSString *code = [comps queryItemsDictionary][@"code"];
            if ([code length]) {
                [self processAuthCode:code];
                return YES;
            }
        }
    }
    return NO;
}

- (WebWindow *)webWindow {
    return (id)self.window;
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    NSURL *URL = navigationAction.request.URL;
    if ([self handleCodeURL:URL]) {
        decisionHandler(WKNavigationActionPolicyCancel);
    } else {
        decisionHandler(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation {
    _progress.hidden = YES;
    [_progress stopAnimation:nil];
    
    [self webWindow].secure = webView.hasOnlySecureContent;
    _back.enabled = _web.canGoBack;
    _forward.enabled = _web.canGoForward;
}

- (void)handleWebError:(NSError *)error {
    _failed = YES;
    
    _progress.hidden = YES;
    [_progress stopAnimation:nil];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [error localizedDescription];
    
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [self handleWebError:error];
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    [self handleWebError:error];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self webWindow].secure = webView.hasOnlySecureContent;
}

- (void)showCerts:(id)sender {
    if ([_web respondsToSelector:@selector(certificateChain)]) {
        SFCertificatePanel *panel = [SFCertificatePanel new];
        [panel beginSheetForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:NULL certificates:_web.certificateChain showGroup:YES];
    }
}

- (void)show {
    BOOL useBrowser = [[Auth allLogins] count] == 0 && [[ABTesting sharedTesting] usesBrowserBasedOAuth];
    
    if (useBrowser) {
        [[NSWorkspace sharedWorkspace] openURL:[self startURL]];
        return;
    }
    
    CFRetain((__bridge CFTypeRef)self);
    
    [_authController.window close];
    
    NSWindow *myWindow = [self window];
    [myWindow setFrame:CGRectMake(0, 0, 500, 690) display:NO];
    [myWindow center];
    
    [myWindow makeKeyAndOrderFront:nil];
}

- (void)windowWillClose:(NSNotification *)notification {
    if (!_complete) {
        [_authController showWindow:nil];
    }
    CFRelease((__bridge CFTypeRef)self);
}

- (IBAction)goBack:(id)sender {
    [_web goBack];
}

- (IBAction)goForward:(id)sender {
    [_web goForward];
}

- (IBAction)reload:(id)sender {
    if (_failed) {
        _failed = NO;
        _progress.hidden = NO;
        [_progress startAnimation:nil];
        
        [_web loadRequest:[self startRequest]];
    } else {
        [_web reload];
    }
}

- (void)reachabilityChanged:(NSNotification *)note {
    if ([note.userInfo[ReachabilityKey] boolValue] && _failed) {
        [self reload:nil];
    }
}

@end

@interface WebWindow ()

@property NSButton *secureButton;

@end

@implementation WebWindow

- (id)init {
    if (self = [super init]) {
        [self setupButton];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self setupButton];
    }
    return self;
}

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if (self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag]) {
        [self setupButton];
    }
    return self;
}

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag screen:(NSScreen *)screen
{
    if (self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag screen:screen]) {
        [self setupButton];
    }
    return self;
}

- (NSView *)titleBarView {
    return [[self standardWindowButton:NSWindowCloseButton] superview];
}

- (void)setupButton {
    NSImage *image = [NSImage imageNamed:NSImageNameLockLockedTemplate];
    [image setTemplate:YES];
    _secureButton = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 10, 12)];
    NSButtonCell *cell = _secureButton.cell;
    cell.imageScaling = NSImageScaleAxesIndependently;
    _secureButton.bezelStyle = NSRecessedBezelStyle;
    _secureButton.bordered = NO;
    _secureButton.image = image;
    _secureButton.action = @selector(buttonClicked:);
    _secureButton.target = self;
    _secureButton.hidden = YES;
    
    NSView *titleBarView = [self titleBarView];
    
    [titleBarView addSubview:_secureButton];
    [self layoutWindowButtons];
}

- (void)layoutIfNeeded {
    [super layoutIfNeeded];
    [self layoutWindowButtons];
}

- (void)layoutWindowButtons {
    NSView *titleBarView = [self titleBarView];
    
    CGFloat width = titleBarView.frame.size.width;
    CGFloat height = titleBarView.frame.size.height;
    
    CGRect frame = CGRectMake(width - 15.0 - _secureButton.frame.size.width,
                              height - _secureButton.frame.size.height - 5.0,
                              _secureButton.frame.size.width, _secureButton.frame.size.height);
    _secureButton.frame = frame;
}


- (void)buttonClicked:(id)sender {
    [self sendAction:self.secureAction toTarget:self.secureTarget];
}

- (void)setSecure:(BOOL)secure {
    _secureButton.hidden = !secure;
}

@end

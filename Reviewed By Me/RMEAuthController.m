//
//  RMEAuthController.m
//  ShipHub
//
//  Created by James Howard on 8/11/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEAuthController.h"

#import "Analytics.h"
#import "Auth.h"
#import "Error.h"
#import "Extras.h"
#import "ButtonToolbarItem.h"
#import "Reachability.h"
#import "WebSession.h"
#import "ServerConnection.h"

#import <WebKit/WebKit.h>
#import <SecurityInterface/SFCertificatePanel.h>

@interface WebWindow : NSWindow

@property (nonatomic, getter=isSecure) BOOL secure;
@property (weak) id secureTarget;
@property (assign) SEL secureAction;

@end

@interface RMEAuthController () <WKUIDelegate, WKNavigationDelegate>

@property IBOutlet NSView *webContainer;
@property WKWebView *web;
@property IBOutlet ButtonToolbarItem *back;
@property IBOutlet ButtonToolbarItem *forward;
@property IBOutlet ButtonToolbarItem *reload;
@property IBOutlet NSProgressIndicator *progress;

@property IBOutlet NSButton *secureButton;

@property (getter=isComplete) BOOL complete;
@property BOOL failed;

@property (copy) NSArray<NSHTTPCookie *> *sessionCookies;

@end

@implementation RMEAuthController

- (NSString *)windowNibName { return @"RMEAuthController"; }

- (void)dealloc {
    _web.UIDelegate = nil;
    _web.navigationDelegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:ReachabilityDidChangeNotification object:[Reachability sharedInstance]];
}

- (void)reset {
    [self window];
    
    _complete = NO;
    _web.hidden = YES;
    _progress.hidden = NO;
    [_progress startAnimation:nil];
    [_web loadRequest:[self startRequest]];
}

- (NSString *)ghWebHost {
    return @"github.com";
}

- (NSString *)ghApiHost {
    return @"api.github.com";
}

- (NSString *)clientID {
    return @"02b864a5a88ee43c6b68";
}

- (NSString *)clientSecret {
    return @"0ec782e86868a726f90149587983ac3498bb0713";
}

- (NSString *)scopes {
    return @"user,repo";
}

- (NSURL *)startURL {
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = [self ghWebHost];
    comps.path = @"/login/oauth/authorize";
    comps.queryItemsDictionary = @{ @"client_id" : [self clientID],
                                    @"scope" : [self scopes] };
    return comps.URL;
}

- (NSURLRequest *)startRequest {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self startURL]];
    return request;
}

- (void)processAuthCode:(NSString *)authCode {
    /*
      req = requests.post("https://github.com/login/oauth/access_token", params={
        "client_id": client_id,
        "client_secret": client_secret,
        "code": code
      }, headers={
        "Accept": "application/json"
      }, timeout=50.0)
      req.raise_for_status()
      result = req.json()
      return result["access_token"]
    */
    
    _web.hidden = YES;
    _progress.hidden = NO;
    [_progress startAnimation:nil];
    
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = [self ghWebHost];
    comps.path = @"/login/oauth/access_token";
    comps.queryItemsDictionary = @{ @"client_id" : [self clientID],
                                    @"client_secret" : [self clientSecret],
                                    @"code" : authCode };
    
    NSMutableURLRequest *r = [NSMutableURLRequest requestWithURL:comps.URL];
    r.HTTPMethod = @"POST";
    [r setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:r completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSString *token = nil;
        
        if (!data && !error) {
            error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        if (!error) {
            NSError *jsonErr = nil;
            NSDictionary *x = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            if (jsonErr) {
                error = jsonErr;
            } else if (![x isKindOfClass:[NSDictionary class]] || ![x[@"access_token"] isKindOfClass:[NSString class]]) {
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            } else {
                token = x[@"access_token"];
            }
        }
        
        RunOnMain(^{
            if (error) {
                [self presentError:error];
            } else {
                [self continueWithToken:token];
            }
        });
    }] resume];
}

- (BOOL)presentError:(NSError *)error {
    [_progress stopAnimation:nil];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Unable to sign in", nil);
    alert.informativeText = [error localizedDescription];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        [self reset];
    }];
    return YES;
}

- (void)continueWithToken:(NSString *)token {
    // get the user info
    NSMutableDictionary *accountDict = [NSMutableDictionary new];
    accountDict[@"ghHost"] = [self ghApiHost];
    accountDict[@"shipHost"] = [self ghApiHost];
    
    AuthAccount *tAccount = [[AuthAccount alloc] initWithDictionary:accountDict];
    Auth *tAuth = [Auth temporaryAuthWithAccount:tAccount ghToken:token];
    ServerConnection *conn = [[ServerConnection alloc] initWithAuth:tAuth];
    
    [conn perform:@"GET" on:@"/user" body:nil completion:^(id jsonResponse, NSError *error) {
        RunOnMain(^{
            if (error) {
                [self presentError:error];
            } else {
                [self finishWithUser:jsonResponse token:token];
            }
        });
        
    }];
}

- (void)finishWithUser:(NSDictionary *)user token:(NSString *)token {
    NSMutableDictionary *accountDict = [user mutableCopy];
    accountDict[@"ghHost"] = [self ghApiHost];
    accountDict[@"shipHost"] = [self ghApiHost];
    accountDict[@"ghIdentifier"] = accountDict[@"identifier"] = accountDict[@"id"];
    
    AuthAccount *account = [[AuthAccount alloc] initWithDictionary:accountDict];
    Auth *auth = [Auth authWithAccount:account shipToken:token ghToken:token sessionCookies:self.sessionCookies];
    
    [self.delegate authController:self authenticated:auth newAccount:YES];
}

- (BOOL)handleCodeURL:(NSURL *)URL {
    NSURLComponents *comps = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    if ([@[@"realartists.com", @"beta.realartists.com", @"www.realartists.com"] containsObject:comps.host]) {
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
    _web.hidden = NO;
    _progress.hidden = YES;
    [_progress stopAnimation:nil];
    
    [self webWindow].secure = webView.hasOnlySecureContent;
    _back.enabled = _web.canGoBack;
    _forward.enabled = _web.canGoForward;
}

- (void)handleWebError:(NSError *)error {
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        return;
    }
    
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

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)(navigationResponse.response);
    if ([[http.URL host] isEqualToString:[[self startURL] host]]) {
        NSArray *cookies = [WebSession sessionCookiesInResponse:http];
        if (cookies) {
            DebugLog(@"Snarfed session cookies %@", cookies);
            self.sessionCookies = cookies;
        }
    }
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSString *URLPath = webView.URL.path;
    if ([URLPath isEqualToString:@"/login"]) {
        [[Analytics sharedInstance] track:@"Login Shown"];
    } else if ([URLPath isEqualToString:@"/sessions/two-factor"]) {
        [[Analytics sharedInstance] track:@"2FA Shown"];
    }
    [self webWindow].secure = webView.hasOnlySecureContent;
}

- (void)showCerts:(id)sender {
    if ([_web respondsToSelector:@selector(certificateChain)]) {
        SFCertificatePanel *panel = [SFCertificatePanel new];
        [panel beginSheetForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:NULL certificates:_web.certificateChain showGroup:YES];
    }
}

- (void)showWindow:(id)sender {
    if (![[self window] isVisible]) {
        NSWindow *myWindow = [self window];
        [myWindow setFrame:CGRectMake(0, 0, 500, 690) display:NO];
        [myWindow center];
        [self reset];
    }
    [super showWindow:sender];
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

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if (self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag]) {
        [self setupButton];
    }
    return self;
}

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag screen:(NSScreen *)screen
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

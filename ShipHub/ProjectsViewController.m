//
//  ProjectsViewController.m
//  ShipHub
//
//  Created by James Howard on 9/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "ProjectsViewController.h"

#import "Auth.h"
#import "DataStore.h"
#import "Repo.h"
#import "Project.h"
#import "Extras.h"
#import "WebSession.h"
#import "IssueDocumentController.h"
#import "IssueIdentifier.h"

#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

@interface ProjectsViewController () <WKUIDelegate, WKNavigationDelegate>

@property WKWebView *web;
@property BOOL loggingIn;

@end

@implementation ProjectsViewController

- (void)loadView {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = [WKWebsiteDataStore nonPersistentDataStore];
    _web = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 600, 600) configuration:config];
    
    _web.UIDelegate = self;
    _web.navigationDelegate = self;
    
    self.view = _web;
}

- (NSSize)preferredMinimumSize {
    NSScreen *myScreen = self.view.window.screen ?: [NSScreen mainScreen];
    CGFloat idealWidth = 1040.0;
    CGFloat sidebarWidth = 240.0;
    if (myScreen.visibleFrame.size.width < idealWidth + sidebarWidth) {
        return NSMakeSize(600.0, 500);
    } else {
        return NSMakeSize(idealWidth, 500.0);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)setRepresentedObject:(NSDictionary *)representedObject {
    NSDictionary *current = self.representedObject;
    
    [super setRepresentedObject:representedObject];
    
    Repo *oldRepo = current[@"repo"];
    Project *oldProject = current[@"project"];
    
    Repo *repo = representedObject[@"repo"];
    Project *project = representedObject[@"project"];
    
    if ([NSObject object:repo.identifier isEqual:oldRepo.identifier]
        && [NSObject object:project.identifier isEqual:oldProject.identifier])
    {
        return; // nothing changed
    }
    
    [self loadProject];
}

- (NSURL *)projectURL {
    NSDictionary *representedObject = self.representedObject;
    
    Repo *repo = representedObject[@"repo"];
    Project *project = representedObject[@"project"];
    
    if (!repo || !project)
        return nil;
    
    Auth *auth = [[DataStore activeStore] auth];
    WebSession *webSession = auth.webSession;
    
    NSString *host = webSession.host;
    
    NSString *URLStr = [NSString stringWithFormat:@"https://%@/%@/projects/%@?fullscreen=true", host, repo.fullName, project.number];
    NSURL *URL = [NSURL URLWithString:URLStr];
    
    return URL;
}

- (void)loadProject {
    NSDictionary *representedObject = self.representedObject;
    
    Project *project = representedObject[@"project"];
    
    self.title = project.name ?: NSLocalizedString(@"Project", nil);
    
    Auth *auth = [[DataStore activeStore] auth];
    WebSession *webSession = auth.webSession;
    
    NSURL *URL = [self projectURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [webSession addToRequest:request];
    [_web loadRequest:request];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if (_loggingIn) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        NSURL *URL = navigationAction.request.URL;
        if ([URL isEqual:[self projectURL]]) {
            decisionHandler(WKNavigationActionPolicyAllow);
        } else {
            id issueIdentifier = [NSString issueIdentifierWithGitHubURL:URL];
            
            if (issueIdentifier) {
                [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:issueIdentifier];
            } else {
                [[NSWorkspace sharedWorkspace] openURL:URL];
            }

            decisionHandler(WKNavigationActionPolicyCancel);
        }
    }
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    Auth *auth = [[DataStore activeStore] auth];
    WebSession *webSession = auth.webSession;
    
    NSHTTPURLResponse *http = (NSHTTPURLResponse *)(navigationResponse.response);
    BOOL updated = [webSession updateSessionWithResponse:http];
    
    if (http.statusCode == 404) {
        decisionHandler(WKNavigationResponsePolicyCancel);
        [self login];
    } else if (_loggingIn && updated) {
        _loggingIn = NO;
        decisionHandler(WKNavigationResponsePolicyCancel);
        [self loadProject];
    } else {
        decisionHandler(WKNavigationResponsePolicyAllow);
    }
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    NSURL *URL = webView.URL;
    if ([URL isEqual:[self projectURL]]) {
        [self hideExitFullscreen];
    }
}

- (void)hideExitFullscreen {
    NSString *nonFullscreen = [[[self projectURL] description] stringByReplacingOccurrencesOfString:@"?fullscreen=true" withString:@""];
    NSString *js =
    @"var anchors = document.getElementsByTagName('a');\n"
    @"for (var i = 0; i < anchors.length; i++) {\n"
    @"  var a = anchors[i];\n"
    @"  if (a.href == '%@') {\n"
    @"    a.style.display = 'none';\n"
    @"  }\n"
    @"}\n";
    js = [NSString stringWithFormat:js, nonFullscreen];
    [_web evaluateJavaScript:js completionHandler:^(id result, NSError * error) {
        if (error) {
            ErrLog(@"%@", error);
        }
    }];
}

- (void)login {
    _loggingIn = YES;
    
    Auth *auth = [[DataStore activeStore] auth];
    WebSession *webSession = auth.webSession;
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/login", webSession.host]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    [webSession addToRequest:request];
    [_web loadRequest:request];
}


@end

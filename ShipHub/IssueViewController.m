//
//  IssueViewController.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueViewController.h"

#import "APIProxy.h"
#import "Auth.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Issue.h"
#import "IssueDocumentController.h"
#import "IssueIdentifier.h"
#import "JSON.h"
#import "User.h"
#import "WebKitExtras.h"

#import <WebKit/WebKit.h>

@interface IssueViewController () <WKNavigationDelegate> {
    BOOL _didFinishLoading;
    NSString *_javaScriptToRun;
}

@property WKWebView *web;

@end

@implementation IssueViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(issueDidUpdate:) name:DataStoreDidUpdateProblemsNotification object:nil];
    
    WKPreferences *prefs = [WKPreferences new];
#if DEBUG
    [prefs setValue:@YES forKey:@"developerExtrasEnabled"];
#endif
    
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKUserContentController *userContent = [WKUserContentController new];
    config.userContentController = userContent;
    config.preferences = prefs;
    DebugLog(@"Persistent data store: %@ (isPersistent:%d)", config.websiteDataStore, config.websiteDataStore.persistent);

    WKUserScript *inApp = [[WKUserScript alloc] initWithSource:@"window.inApp = true" injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [userContent addUserScript:inApp];
    
    __weak __typeof(self) weakSelf = self;
    [userContent addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf proxyAPI:msg];
    } name:@"api"];
    
    _web = [[WKWebView alloc] initWithFrame:CGRectMake(0, 0, 600, 600) configuration:config];
    _web.navigationDelegate = self;
    self.view = _web;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *indexPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"IssueWeb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:indexPath]];
    [_web loadRequest:request];
    
    if (!_issue) {
        [self configureNewIssue];
    }
}

- (void)configureNewIssue {
    [self evaluateJavaScript:@"configureNewIssue();"];
}

- (NSString *)issueStateJSON:(Issue *)issue {
    MetadataStore *meta = [[DataStore activeStore] metadataStore];
    
    NSMutableDictionary *state = [NSMutableDictionary new];
    state[@"issue"] = issue;
    
    state[@"me"] = [User me];
    state[@"ghToken"] = [[[DataStore activeStore] auth] ghToken];
    state[@"repos"] = [meta activeRepos];
    
    if (issue.repository) {
        state[@"assignees"] = [meta assigneesForRepo:issue.repository];
        state[@"milestones"] = [meta activeMilestonesForRepo:issue.repository];
        state[@"labels"] = [meta labelsForRepo:issue.repository];
    } else {
        state[@"assignees"] = @[];
        state[@"milestones"] = @[];
        state[@"labels"] = @[];
    }
    
    return [JSON stringifyObject:state withNameTransformer:[JSON underbarsAndIDNameTransformer]];
}

- (void)setIssue:(Issue *)issue {
    DebugLog(@"%@", issue);
    _issue = issue;
    NSString *issueJSON = [self issueStateJSON:issue];
    NSString *js = [NSString stringWithFormat:@"applyIssueState(%@)", issueJSON];
    DebugLog(@"%@", js);
    [self evaluateJavaScript:js];
    self.title = issue.title ?: NSLocalizedString(@"Untitled Issue", nil);
}

- (void)issueDidUpdate:(NSNotification *)note {
    if (!_issue) return;
    if ([note object] == [DataStore activeStore]) {
        NSArray *updated = note.userInfo[DataStoreUpdatedProblemsKey];
        if ([updated containsObject:_issue.fullIdentifier]) {
            [[DataStore activeStore] loadFullIssue:_issue.fullIdentifier completion:^(Issue *issue, NSError *error) {
                if (issue) {
                    self.issue = issue;
                }
            }];
        }
    }
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

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    if (navigationAction.navigationType == WKNavigationTypeReload) {
        [self reload:nil];
        decisionHandler(WKNavigationActionPolicyCancel);
    } else if (navigationAction.navigationType == WKNavigationTypeOther) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        NSURL *URL = navigationAction.request.URL;
        id issueIdentifier = [NSString issueIdentifierWithGitHubURL:URL];
        
        if (issueIdentifier) {
            [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:issueIdentifier];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:URL];
        }
        
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void)proxyAPI:(WKScriptMessage *)msg {
    DebugLog(@"%@", msg.body);
    
    APIProxy *proxy = [APIProxy proxyWithRequest:msg.body completion:^(NSString *jsonResult, NSError *err) {
        NSString *callback;
        if (err) {
            callback = [NSString stringWithFormat:@"apiCallback(%@, null, %@)", msg.body[@"handle"], [JSON stringifyObject:[err localizedDescription]]];
        } else {
            callback = [NSString stringWithFormat:@"apiCallback(%@, %@, null)", msg.body[@"handle"], jsonResult];
        }
        DebugLog(@"%@", callback);
        [self evaluateJavaScript:callback];
    }];
    [proxy resume];
}

- (IBAction)reload:(id)sender {
    if (_issue) {
        [[DataStore activeStore] checkForIssueUpdates:_issue.fullIdentifier];
    }
}

@end

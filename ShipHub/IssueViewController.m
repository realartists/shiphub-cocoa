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
#import "Extras.h"
#import "MetadataStore.h"
#import "Issue.h"
#import "IssueDocumentController.h"
#import "IssueIdentifier.h"
#import "JSON.h"
#import "User.h"
#import "WebKitExtras.h"

#import <WebKit/WebKit.h>

@interface IssueViewController () <WebFrameLoadDelegate, WebUIDelegate, WebPolicyDelegate> {
    BOOL _didFinishLoading;
    NSMutableArray *_javaScriptToRun;
}

// Why legacy WebView?
// Because WKWebView doesn't support everything we need :(
// See https://bugs.webkit.org/show_bug.cgi?id=137759
@property WebView *web;

@end

@implementation IssueViewController

- (void)dealloc {
    _web.UIDelegate = nil;
    _web.frameLoadDelegate = nil;
    _web.policyDelegate = nil;
    [_web close];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(issueDidUpdate:) name:DataStoreDidUpdateProblemsNotification object:nil];
    
    _web = [[WebView alloc] initWithFrame:CGRectMake(0, 0, 600, 600) frameName:nil groupName:nil];
    _web.drawsBackground = NO;
    _web.UIDelegate = self;
    _web.frameLoadDelegate = self;
    _web.policyDelegate = self;
    
    self.view = _web;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *indexPath = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"IssueWeb"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:indexPath]];
    [_web.mainFrame loadRequest:request];
}

- (void)configureNewIssue {
    [self evaluateJavaScript:@"configureNewIssue();"];
}

- (NSString *)issueStateJSON:(Issue *)issue {
    MetadataStore *meta = [[DataStore activeStore] metadataStore];
    
    NSMutableDictionary *state = [NSMutableDictionary new];
    state[@"issue"] = issue;
    
    state[@"me"] = [User me];
    state[@"token"] = [[[DataStore activeStore] auth] ghToken];
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

- (void)updateTitle {
    self.title = _issue.title ?: NSLocalizedString(@"New Issue", nil);
}

- (void)setIssue:(Issue *)issue {
    DebugLog(@"%@", issue);
    _issue = issue;
    NSString *issueJSON = [self issueStateJSON:issue];
    NSString *js = [NSString stringWithFormat:@"applyIssueState(%@)", issueJSON];
    DebugLog(@"%@", js);
    [self evaluateJavaScript:js];
    [self updateTitle];
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
        if (!_javaScriptToRun) {
            _javaScriptToRun = [NSMutableArray new];
        }
        [_javaScriptToRun addObject:js];
    } else {
        [_web stringByEvaluatingJavaScriptFromString:js];
    }
}

#pragma mark - WebUIDelegate

- (void)webView:(WebView *)sender runOpenPanelForFileButtonWithResultListener:(id<WebOpenPanelResultListener>)resultListener allowMultipleFiles:(BOOL)allowMultipleFiles
{
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = allowMultipleFiles;
    
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [resultListener chooseFilenames:[panel.URLs arrayByMappingObjects:^id(NSURL * obj) {
                return [obj path];
            }]];
        } else {
            [resultListener cancel];
        }
    }];
}

#pragma mark - WebFrameLoadDelegate

- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame {
    __weak __typeof(self) weakSelf = self;
    [windowObject addScriptMessageHandlerBlock:^(id msg) {
        [weakSelf proxyAPI:msg];
    } name:@"inAppAPI"];
    
    NSString *setupJS =
    @"window.inApp = true;\n"
    @"window.postAppMessage = function(msg) { window.inAppAPI.postMessage(msg); }\n";
    
    NSString *apiToken = [[[DataStore activeStore] auth] ghToken];
    setupJS = [setupJS stringByAppendingFormat:@"window.setAPIToken(\"%@\");\n", apiToken];
    
    [windowObject evaluateWebScript:setupJS];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    _didFinishLoading = YES;
    NSArray *toRun = _javaScriptToRun;
    _javaScriptToRun = nil;
    for (NSString *script in toRun) {
        [self evaluateJavaScript:script];
    }
}

#pragma mark - WebPolicyDelegate

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    DebugLog(@"%@", actionInformation);
    
    WebNavigationType navigationType = [actionInformation[WebActionNavigationTypeKey] integerValue];
    
    if (navigationType == WebNavigationTypeReload) {
        [self reload:nil];
        [listener ignore];
    } else if (navigationType == WebNavigationTypeOther) {
        [listener use];
    } else {
        NSURL *URL = actionInformation[WebActionOriginalURLKey];
        id issueIdentifier = [NSString issueIdentifierWithGitHubURL:URL];
        
        if (issueIdentifier) {
            [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:issueIdentifier];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:URL];
        }
        
        [listener ignore];
    }
}

#pragma mark - Javascript Bridge

- (void)proxyAPI:(NSDictionary *)msg {
    DebugLog(@"%@", msg);
    
    APIProxy *proxy = [APIProxy proxyWithRequest:msg existingIssue:_issue completion:^(NSString *jsonResult, NSError *err) {
        NSString *callback;
        if (err) {
            callback = [NSString stringWithFormat:@"apiCallback(%@, null, %@)", msg[@"handle"], [JSON stringifyObject:[err localizedDescription]]];
        } else {
            callback = [NSString stringWithFormat:@"apiCallback(%@, %@, null)", msg[@"handle"], jsonResult];
        }
        DebugLog(@"%@", callback);
        [self evaluateJavaScript:callback];
    }];
    [proxy setUpdatedIssueHandler:^(Issue *updatedIssue) {
        _issue = updatedIssue;
        [self updateTitle];
    }];
    [proxy resume];
}

#pragma mark -

- (IBAction)reload:(id)sender {
    if (_issue) {
        [[DataStore activeStore] checkForIssueUpdates:_issue.fullIdentifier];
    }
}

@end

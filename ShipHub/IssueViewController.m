//
//  IssueViewController.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueViewController.h"

#import "APIProxy.h"
#import "AttachmentManager.h"
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
    NSInteger _pastedImageCount;
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
    _web.hidden = NO;
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
    dispatch_assert_current_queue(dispatch_get_main_queue());
    DebugLog(@"%@", issue);
    _issue = issue;
    NSString *issueJSON = [self issueStateJSON:issue];
    NSString *js = [NSString stringWithFormat:@"applyIssueState(%@)", issueJSON];
    DebugLog(@"%@", js);
    [self evaluateJavaScript:js];
    [self updateTitle];
    _web.hidden = _issue == nil;
}

- (void)setColumnBrowser:(BOOL)columnBrowser {
    _columnBrowser = columnBrowser;
    
    [self evaluateJavaScript:
     [NSString stringWithFormat:
      @"window.setInColumnBrowser(%@)",
      (_columnBrowser ? @"true" : @"false")]];
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

- (void)webView:(WebView *)sender runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WebFrame *)frame
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
}

#pragma mark - WebFrameLoadDelegate

- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame {
    __weak __typeof(self) weakSelf = self;
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf proxyAPI:msg];
    } name:@"inAppAPI"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf pasteHelper:msg];
    } name:@"inAppPasteHelper"];
    
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

- (NSString *)placeholderWithWrapper:(NSFileWrapper *)wrapper {
    NSString *filename = wrapper.preferredFilename ?: @"attachment";
    if ([wrapper isImageType]) {
        return [NSString stringWithFormat:@"![Uploading %@](...)", filename];
    } else {
        return [NSString stringWithFormat:@"[Uploading %@](...)", filename];
    }
}

- (NSString *)linkWithWrapper:(NSFileWrapper *)wrapper URL:(NSURL *)linkURL {
    NSString *filename = wrapper.preferredFilename ?: @"attachment";
    if ([wrapper isImageType]) {
        return [NSString stringWithFormat:@"![%@](%@)", filename, linkURL];
    } else {
        return [NSString stringWithFormat:@"[%@](%@)", filename, linkURL];
    }
}

- (void)pasteWrappers:(NSArray<NSFileWrapper *> *)wrappers handle:(NSNumber *)handle {
    NSMutableString *pasteString = [NSMutableString new];
    
    __block NSInteger pendingUploads = wrappers.count;
    for (NSFileWrapper *wrapper in wrappers) {
        NSString *placeholder = [self placeholderWithWrapper:wrapper];
        
        [[AttachmentManager sharedManager] uploadAttachment:wrapper completion:^(NSURL *destinationURL, NSError *error) {
            NSString *js = nil;
            
            dispatch_assert_current_queue(dispatch_get_main_queue());
            
            if (error) {
                js = [NSString stringWithFormat:@"pasteCallback(%@, 'uploadFailed', %@)", handle, [JSON stringifyObject:@{@"placeholder": placeholder, @"err": [error localizedDescription]}]];
            } else {
                NSString *link = [self linkWithWrapper:wrapper URL:destinationURL];
                js = [NSString stringWithFormat:@"pasteCallback(%@, 'uploadFinished', %@)", handle, [JSON stringifyObject:@{@"placeholder": placeholder, @"link": link}]];
            }
            
            DebugLog(@"%@", js);
            [self evaluateJavaScript:js];
            
            pendingUploads--;
            
            if (pendingUploads == 0) {
                js = [NSString stringWithFormat:@"pasteCallback(%@, 'complete')", handle];
                [self evaluateJavaScript:js];
            }
        }];
        
        [pasteString appendFormat:@"%@\n", placeholder];
    }
    
    NSString *js = [NSString stringWithFormat:
                    @"pasteCallback(%@, 'pasteText', %@);\n"
                    @"pasteCallback(%@, 'uploadsStarted', %tu);\n",
                    handle, [JSON stringifyObject:pasteString],
                    handle, wrappers.count];
    DebugLog(@"%@", js);
    [self evaluateJavaScript:js];
}

- (void)pasteHelper:(NSDictionary *)msg {
    NSNumber *handle = msg[@"handle"];
    
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    
    NSString *callback;
    
#if DEBUG
    for (NSPasteboardItem *item in pasteboard.pasteboardItems) {
        DebugLog(@"Saw item %@, with types %@", item, item.types);
    }
#endif
    
    if ([pasteboard canReadItemWithDataConformingToTypes:@[NSFilenamesPboardType, NSFilesPromisePboardType, (__bridge NSString *)kPasteboardTypeFileURLPromise, (__bridge NSString *)kUTTypeFileURL]]) {
        // file data
        DebugLog(@"paste files: %@", pasteboard.pasteboardItems);
        
        NSMutableArray *wrappers = [NSMutableArray new];
        for (NSPasteboardItem *item in pasteboard.pasteboardItems) {
            NSString *URLString = [item stringForType:(__bridge NSString *)kUTTypeFileURL];
            if (URLString) {
                NSURL *URL = [NSURL URLWithString:URLString];
                NSFileWrapper *wrapper = [[NSFileWrapper alloc] initWithURL:URL options:0 error:NULL];
                [wrappers addObject:wrapper];
            }
        }
        
        [self pasteWrappers:wrappers handle:handle];
    } else if ([pasteboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeRTFD]]) {
        // find out if the rich text contains files in it we need to upload
        NSData *data = [pasteboard dataForType:NSPasteboardTypeRTFD];
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithRTFD:data documentAttributes:nil];
        
        DebugLog(@"paste attrStr: %@", attrStr);
        
        // find all the attachments
        NSMutableArray *attachments = [NSMutableArray new];
        NSMutableArray *ranges = [NSMutableArray new];
        [attrStr enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, attrStr.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
            if ([value isKindOfClass:[NSTextAttachment class]]) {
                NSFileWrapper *wrapper = [value fileWrapper];
                if (wrapper) {
                    [attachments addObject:wrapper];
                    [ranges addObject:[NSValue valueWithRange:range]];
                }
            }
        }];
        
        if (attachments.count == 0) {
            NSString *js = [NSString stringWithFormat:
                            @"pasteCallback(%@, 'pasteText', %@);\n"
                            @"pasteCallback(%@, 'completed');\n",
                            handle, [JSON stringifyObject:[attrStr string]],
                            handle];
            [self evaluateJavaScript:js];
        } else {
            NSMutableAttributedString *pasteStr = [attrStr mutableCopy];
            
            __block NSInteger pendingUploads = attachments.count;
            for (NSInteger i = pendingUploads; i > 0; i--) {
                NSRange range = [ranges[i-1] rangeValue];
                NSFileWrapper *attachment = attachments[i-1];
                
                NSString *placeholder = [self placeholderWithWrapper:attachment];
                [pasteStr replaceCharactersInRange:range withString:placeholder];
                
                [[AttachmentManager sharedManager] uploadAttachment:attachment completion:^(NSURL *destinationURL, NSError *error) {
                    NSString *js = nil;
                    
                    dispatch_assert_current_queue(dispatch_get_main_queue());
                    
                    if (error) {
                        js = [NSString stringWithFormat:@"pasteCallback(%@, 'uploadFailed', %@)", handle, [JSON stringifyObject:@{@"placeholder": placeholder, @"err": [error localizedDescription]}]];
                    } else {
                        NSString *link = [self linkWithWrapper:attachment URL:destinationURL];
                        js = [NSString stringWithFormat:@"pasteCallback(%@, 'uploadFinished', %@)", handle, [JSON stringifyObject:@{@"placeholder": placeholder, @"link": link}]];
                    }
                    
                    DebugLog(@"%@", js);
                    [self evaluateJavaScript:js];
                    
                    pendingUploads--;
                    
                    if (pendingUploads == 0) {
                        js = [NSString stringWithFormat:@"pasteCallback(%@, 'complete')", handle];
                        [self evaluateJavaScript:js];
                    }
                }];
            }
            
            NSString *js = [NSString stringWithFormat:
                            @"pasteCallback(%@, 'pasteText', %@);\n"
                            @"pasteCallback(%@, 'uploadsStarted', %tu);\n",
                            handle, [JSON stringifyObject:[pasteStr string]],
                            handle, attachments.count];
            DebugLog(@"%@", js);
            [self evaluateJavaScript:js];
        }
        
    } else if ([pasteboard canReadItemWithDataConformingToTypes:@[NSPasteboardTypeString]]) {
        // just plain text
        NSString *contents = [pasteboard stringForType:NSPasteboardTypeString];
        callback = [NSString stringWithFormat:@"pasteCallback(%@, 'pasteText', %@);", handle, [JSON stringifyObject:contents]];
        DebugLog(@"paste text: %@", callback);
        [self evaluateJavaScript:callback];
        
        callback = [NSString stringWithFormat:@"pasteCallback(%@, 'completed');", handle];
        DebugLog(@"%@", callback);
        [self evaluateJavaScript:callback];
    } else if ([pasteboard canReadItemWithDataConformingToTypes:@[(__bridge NSString *)kUTTypeGIF, NSPasteboardTypePNG, NSPasteboardTypePDF, NSPasteboardTypeTIFF]]) {
        // images
        DebugLog(@"paste images: %@", pasteboard.pasteboardItems);
        NSMutableArray *imageWrappers = [NSMutableArray new];
        for (NSPasteboardItem *item in pasteboard.pasteboardItems) {
            NSData *imgData = [item dataForType:(__bridge NSString *)kUTTypeGIF];
            NSString *ext = @"gif";
            if (!imgData) {
                imgData = [item dataForType:NSPasteboardTypePNG];
                ext = @"png";
            }
            if (!imgData) {
                imgData = [item dataForType:NSPasteboardTypePDF];
                ext = @"pdf";
            }
            if (!imgData) {
                imgData = [item dataForType:NSPasteboardTypeTIFF];
                ext = @"tiff";
            }
            
            if (imgData) {
                NSFileWrapper *wrapper = [[NSFileWrapper alloc] initRegularFileWithContents:imgData];
                
                NSString *filename = [NSString stringWithFormat:NSLocalizedString(@"Pasted Image %td.%@", nil), ++_pastedImageCount, ext];
                wrapper.preferredFilename = filename;
                
                [imageWrappers addObject:wrapper];
            }
        }
        
        [self pasteWrappers:imageWrappers handle:handle];
        
    } else {
        // can't read anything
        DebugLog(@"nothing readable in pasteboard: %@", pasteboard.pasteboardItems);
        callback = [NSString stringWithFormat:@"pasteCallback(%@, 'completed');", handle];
        [self evaluateJavaScript:callback];
    }
}

#pragma mark -

- (IBAction)reload:(id)sender {
    if (_issue) {
        [[DataStore activeStore] checkForIssueUpdates:_issue.fullIdentifier];
    }
}

- (IBAction)copyIssueNumber:(id)sender {
    [[_issue fullIdentifier] copyIssueIdentifierToPasteboard:[NSPasteboard generalPasteboard]];
}

- (IBAction)copyIssueNumberWithTitle:(id)sender {
    [[_issue fullIdentifier] copyIssueIdentifierToPasteboard:[NSPasteboard generalPasteboard] withTitle:_issue.title];
}

- (IBAction)copyIssueGitHubURL:(id)sender {
    [[_issue fullIdentifier] copyIssueGitHubURLToPasteboard:[NSPasteboard generalPasteboard]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    return _issue.fullIdentifier != nil;
}

@end

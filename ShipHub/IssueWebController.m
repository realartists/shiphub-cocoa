//
//  IssueWebController.m
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueWebControllerInternal.h"

#import "AppDelegate.h"
#import "AttachmentManager.h"
#import "Auth.h"
#import "CodeSnippetManager.h"
#import "DataStore.h"
#import "EmptyLabelView.h"
#import "Error.h"
#import "Extras.h"
#import "MultiDownloadProgress.h"
#import "JSON.h"
#import "WebKitExtras.h"
#import "DownloadBarViewController.h"
#import "NSFileWrapper+ImageExtras.h"
#import "Reachability.h"
#import "CThemeManager.h"

#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <DHHighlightedWebView/DHHighlightedWebView.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static void fixWebViewInputText(void);

@interface IssueWebView : DHWebView

@property (copy) NSString *dragPasteboardName;

@end

@interface IssueWebController () <WebFrameLoadDelegate, WebUIDelegate, WebPolicyDelegate>
{
    BOOL _didFinishLoading;
    NSMutableArray *_javaScriptToRun;
    NSInteger _pastedImageCount;
    BOOL _useWebpackDevServer;
    
    NSInteger _spellcheckDocumentTag;
    NSDictionary *_spellcheckContextTarget;
    
    BOOL _findBarVisible;
}

// Why legacy WebView?
// Because WKWebView doesn't support everything we need :(
// See https://bugs.webkit.org/show_bug.cgi?id=137759
@property IssueWebView *web;

@property DownloadBarViewController *downloadBar;
@property MultiDownloadProgress *downloadProgress;
@property NSTimer *downloadDebounceTimer;

@property EmptyLabelView *nothingLabel;

@property (strong) NSView *findBarView;
@property (getter=isFindBarVisible) BOOL findBarVisible;
- (void)findBarViewDidChangeHeight;

@end

@implementation IssueWebController

- (id)init {
    if (self = [super init]) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    fixWebViewInputText();
    _useWebpackDevServer = [[NSUserDefaults standardUserDefaults] boolForKey:@"UseWebpackDevServer"];
}

- (void)dealloc {
    IssueWebView *web = _web;
    web.UIDelegate = nil;
    web.frameLoadDelegate = nil;
    web.policyDelegate = nil;
    RunOnMain(^{
        [web close];
    });
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {
    NSView *container = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewDidChangeFrame:) name:NSViewFrameDidChangeNotification object:container];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:ReachabilityDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCodeTheme) name:CThemeDidChangeNotification object:nil];
    
    _web = [[IssueWebView alloc] initWithFrame:container.bounds frameName:nil groupName:nil];
    _web.continuousSpellCheckingEnabled = YES;
    _web.drawsBackground = NO;
    _web.UIDelegate = self;
    _web.frameLoadDelegate = self;
    _web.policyDelegate = self;
    
    [container addSubview:_web];
    
    _nothingLabel = [[EmptyLabelView alloc] initWithFrame:container.bounds];
    _nothingLabel.hidden = YES;
    _nothingLabel.font = [NSFont systemFontOfSize:28.0];
    _nothingLabel.stringValue = NSLocalizedString(@"No Issue Selected", nil);
    [container addSubview:_nothingLabel];
    
    
    self.view = container;
}

- (void)findBarViewDidChangeHeight {
    [self layoutSubviews];
}

- (void)setFindBarVisible:(BOOL)findBarVisible {
    _findBarVisible = findBarVisible;
    if (findBarVisible) {
        if ([self.findBarView superview] != self.view) {
            [self.view addSubview:self.findBarView];
        }
    } else {
        [self.findBarView removeFromSuperview];
    }
    [self layoutSubviews];
}

- (BOOL)isFindBarVisible {
    return _findBarVisible;
}

- (void)viewDidChangeFrame:(NSNotification *)note {
    [self layoutSubviews];
}

- (CGRect)webContentRect {
    return self.view.bounds;
}

- (void)layoutSubviews {
    CGRect b = [self webContentRect];
    if (self.findBarVisible) {
        CGRect f = self.findBarView.frame;
        f.origin.x = 0;
        f.size.width = b.size.width;
        f.origin.y = CGRectGetHeight(b) - f.size.height;
        self.findBarView.frame = f;
        b.size.height -= f.size.height;
    }
    if (_downloadProgress && !_downloadDebounceTimer) {
        CGRect downloadFrame = CGRectMake(0, 0, CGRectGetWidth(b), _downloadBar.view.frame.size.height);
        _downloadBar.view.frame = downloadFrame;
        
        CGRect webFrame = CGRectMake(0, CGRectGetMaxY(downloadFrame), CGRectGetWidth(b), CGRectGetHeight(b) - CGRectGetHeight(downloadFrame));
        _web.frame = webFrame;
    } else {
        _web.frame = b;
        if (_downloadBar.viewLoaded) {
            _downloadBar.view.frame = CGRectMake(0, -_downloadBar.view.frame.size.height, CGRectGetWidth(b), _downloadBar.view.frame.size.height);
        }
    }
    _nothingLabel.frame = _web.frame;
}

- (NSString *)webHtmlFilename {
    ErrLog(@"Subclasses of IssueWebController must implement webHtmlFilename");
    return @"index.html";
}

- (NSString *)webResourcePath {
    return @"IssueWeb";
}

- (NSInteger)webpackDevServerPort {
    return 8080;
}

- (NSURL *)indexURL {
    NSURL *URL;
    if (_useWebpackDevServer) {
        NSString *webpackURLStr = [NSString stringWithFormat:@"http://localhost:%td/%@", [self webpackDevServerPort], [self webHtmlFilename]];
        URL = [NSURL URLWithString:webpackURLStr];
    } else {
        NSString *filename = [self webHtmlFilename];
        URL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:[filename stringByDeletingPathExtension] ofType:[filename pathExtension] inDirectory:[self webResourcePath]]];
    }
    return URL;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *URL = [self indexURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    [_web.mainFrame loadRequest:request];
}

- (void)reachabilityChanged:(NSNotification *)note {
    BOOL reachable = [note.userInfo[ReachabilityKey] boolValue];
    if (reachable && _didFinishLoading) {
        [self evaluateJavaScript:@"if (window.reloadFailedMedia) { window.reloadFailedMedia(); }"];
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

- (void)updateCodeTheme {
    NSDictionary *themeVars = [[CThemeManager sharedManager] activeThemeVariables];
    [self evaluateJavaScript:[NSString stringWithFormat:@"window.setCTheme(%@)", [JSON stringifyObject:themeVars]]];
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

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems {
    NSArray *menuItems = defaultMenuItems;
    
    if (_spellcheckContextTarget) {
        NSDictionary *target = _spellcheckContextTarget;
        _spellcheckContextTarget = nil;
        
        NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];
        NSString *contents = target[@"text"];
        NSArray *guesses = [checker guessesForWordRange:NSMakeRange(0, contents.length) inString:contents language:nil inSpellDocumentWithTag:_spellcheckDocumentTag];
        
        NSMutableArray *items = [NSMutableArray new];
        if ([guesses count] == 0) {
            NSMenuItem *noGuesses = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"No Guesses Found", nil) action:@selector(fixSpelling:) keyEquivalent:@""];
            noGuesses.enabled = NO;
            [items addObject:noGuesses];
        } else {
            
            for (NSString *guess in guesses) {
                NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:guess action:@selector(fixSpelling:) keyEquivalent:@""];
                item.target = self;
                item.representedObject = target;
                [items addObject:item];
            }
        }
        
        [items addObject:[NSMenuItem separatorItem]];
        
        [items addObjectsFromArray:defaultMenuItems];
        
        menuItems = items;
    }
    
    for (NSMenuItem *i in menuItems) {
        switch (i.tag) {
            case 2000: /* WebMenuItemTagOpenLink */
                i.hidden = YES;
            case WebMenuItemTagOpenLinkInNewWindow:
                i.target = self;
                i.action = @selector(openLinkInNewWindow:);
                break;
            case WebMenuItemTagOpenImageInNewWindow:
                i.target = self;
                i.action = @selector(openImageInNewWindow:);
                break;
            case WebMenuItemTagDownloadLinkToDisk:
                i.target = self;
                i.action = @selector(downloadLinkToDisk:);
                break;
            case WebMenuItemTagDownloadImageToDisk:
                i.target = self;
                i.action = @selector(downloadImageToDisk:);
                break;
            default: break;
        }
    }
    
    return menuItems;
}

- (void)fixSpelling:(id)sender {
    NSString *callback = [NSString stringWithFormat:@"window.spellcheckFixer(%@, %@);", [JSON stringifyObject:[sender representedObject]], [JSON stringifyObject:[sender title]]];
    [self evaluateJavaScript:callback];
}

- (void)openLinkInNewWindow:(id)sender {
    NSMenuItem *item = sender;
    NSDictionary *element = item.representedObject;
    NSURL *URL = element[WebElementLinkURLKey];
    if (URL) {
        [[AppDelegate sharedDelegate] openURL:URL];
    }
}

- (void)openImageInNewWindow:(id)sender {
    NSMenuItem *item = sender;
    NSDictionary *element = item.representedObject;
    NSURL *URL = element[WebElementImageURLKey];
    if (URL) {
        [[NSWorkspace sharedWorkspace] openURL:URL];
    }
}

- (void)downloadLinkToDisk:(id)sender {
    NSMenuItem *item = sender;
    NSDictionary *element = item.representedObject;
    NSURL *URL = element[WebElementLinkURLKey];
    if (URL) {
        [self downloadURL:URL];
    }
}

- (void)downloadImageToDisk:(id)sender {
    NSMenuItem *item = sender;
    NSDictionary *element = item.representedObject;
    NSURL *URL = element[WebElementImageURLKey];
    if (URL) {
        [self downloadURL:URL];
    }
}

- (void)downloadURL:(NSURL *)URL {
    // Use a save panel to play nice with sandboxing
    NSSavePanel *panel = [NSSavePanel new];
    
    NSString *UTI = [[URL pathExtension] UTIFromExtension];
    if (UTI) {
        panel.allowedFileTypes = @[UTI];
    }
    
    NSString *filename = [[[URL path] lastPathComponent] stringByRemovingPercentEncoding];
    panel.nameFieldStringValue = filename;
    NSString *downloadsDir = [NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory, NSUserDomainMask, YES) firstObject];
    panel.directoryURL = [NSURL fileURLWithPath:downloadsDir];
    
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            NSURL *destination = panel.URL;
            
            __block __strong NSProgress *downloadProgress = nil;
            
            CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
            
            void (^completionHandler)(NSURL *, NSURLResponse *, NSError *) = ^(NSURL *location, NSURLResponse *response, NSError *error) {
                NSError *err = error;
                if (location) {
                    // Move downloaded file into place
                    [[NSFileManager defaultManager] replaceItemAtURL:destination withItemAtURL:location backupItemName:nil options:NSFileManagerItemReplacementUsingNewMetadataOnly resultingItemURL:NULL error:&err];
                    
                    // Bounce destination directory in dock
                    NSString *parentPath = [[destination path] stringByDeletingLastPathComponent];
                    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"com.apple.DownloadFileFinished" object:parentPath];
                    
                    // Show the item in the finder if it didn't take too long to download or we're being watched
                    RunOnMain(^{
                        CFAbsoluteTime duration = CFAbsoluteTimeGetCurrent() - start;
                        if (duration < 2.0 || [self.view.window isKeyWindow]) {
                            [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[destination]];
                        }
                    });
                }
                if (err && ![err isCancelError]) {
                    ErrLog(@"%@", err);
                    RunOnMain(^{
                        NSAlert *alert = [NSAlert alertWithError:err];
                        [alert beginSheetModalForWindow:self.view.window completionHandler:NULL];
                    });
                }
                
                [self removeDownloadProgress:downloadProgress];
            };
            
            NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:URL completionHandler:completionHandler];
            task.taskDescription = [NSString stringWithFormat:NSLocalizedString(@"Downloading %@ …", nil), filename];
            downloadProgress = [task downloadProgress];
            [self addDownloadProgress:downloadProgress];
            [task resume];
        }
    }];
}

- (void)animateDownloadBar {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        [context setDuration:0.1];
        [context setAllowsImplicitAnimation:YES];
        [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
        [self layoutSubviews];
    } completionHandler:nil];
}

- (void)downloadDebounceTimerFired:(NSTimer *)timer {
    _downloadDebounceTimer = nil;
    if (_downloadProgress) {
        [self animateDownloadBar];
    }
}

- (void)addDownloadProgress:(NSProgress *)progress {
    dispatch_assert_current_queue(dispatch_get_main_queue());
    
    if (!_downloadProgress) {
        if (!_downloadBar) {
            _downloadBar = [DownloadBarViewController new];
            [self.view addSubview:_downloadBar.view];
            [self layoutSubviews];
        }
        
        _downloadProgress = [MultiDownloadProgress new];
        [_downloadProgress addChild:progress];
        _downloadBar.progress = _downloadProgress;
        
        if (!_downloadDebounceTimer) {
            // Prevent download bar from appearing unless we're waiting for more than a beat
            _downloadDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(downloadDebounceTimerFired:) userInfo:nil repeats:NO];
        }
    } else {
        [_downloadProgress addChild:progress];
    }
}

- (void)removeDownloadProgress:(NSProgress *)progress {
    RunOnMain(^{
        [_downloadProgress removeChild:progress];
        if (_downloadProgress.childProgressArray.count == 0) {
            [_downloadDebounceTimer invalidate];
            _downloadDebounceTimer = nil;
            
            _downloadProgress = nil;
            [self animateDownloadBar];
        }
    });
}

#pragma mark - WebFrameLoadDelegate

- (void)registerJavaScriptAPI:(WebScriptObject *)windowObject {
    
}

- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame {
    __weak __typeof(self) weakSelf = self;
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf pasteHelper:msg];
    } name:@"inAppPasteHelper"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf spellcheck:msg];
    } name:@"spellcheck"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf javascriptLoadComplete];
    } name:@"loadComplete"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf loadCodeSnippet:msg];
    } name:@"loadCodeSnippet"];
    
    [self registerJavaScriptAPI:windowObject];
}

- (void)javascriptLoadComplete {
    _didFinishLoading = YES;
    [self configureRaygun];
    [self updateCodeTheme];
    NSArray *toRun = _javaScriptToRun;
    _javaScriptToRun = nil;
    for (NSString *script in toRun) {
        [self evaluateJavaScript:script];
    }
}

- (NSDictionary *)raygunExtraInfo {
    return nil;
}

- (void)configureRaygun {
    Auth *auth = [[DataStore activeStore] auth];
    NSDictionary *user = @{@"identifier":[auth.account.ghIdentifier description], @"login":auth.account.login};
    
    NSString *version = [[NSBundle mainBundle] extras_userAgentString];
    
    NSDictionary *extra = [self raygunExtraInfo];
    
    NSString *js = [NSString stringWithFormat:@"window.configureRaygun(%@, %@, %@);", [JSON stringifyObject:user], [JSON stringifyObject:version], [JSON stringifyObject:extra]];
    [self evaluateJavaScript:js];
}

#pragma mark - WebPolicyDelegate

- (IBAction)reload:(id)sender {
    
}

- (void)reconfigureForReload {
    
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id<WebPolicyDecisionListener>)listener
{
    //DebugLog(@"%@", actionInformation);
    
    WebNavigationType navigationType = [actionInformation[WebActionNavigationTypeKey] integerValue];
    
    if (navigationType == WebNavigationTypeReload) {
        if (_useWebpackDevServer) {
            // The webpack-dev-server page will auto-refresh as the content updates,
            // so reloading needs to be allowed.
            
            _didFinishLoading = NO;
            
            [self reconfigureForReload];
            
            [listener use];
        } else {
            [self reload:nil];
            [listener ignore];
        }
    } else if (navigationType == WebNavigationTypeOther) {
        NSURL *URL = actionInformation[WebActionOriginalURLKey];
        if ([URL isEqual:[self indexURL]]) {
            [listener use];
        } else {
            [listener ignore];
        }
    } else {
        NSURL *URL = actionInformation[WebActionOriginalURLKey];
        [[AppDelegate sharedDelegate] openURL:URL];
        [listener ignore];
    }
}

- (void)webView:(WebView *)webView decidePolicyForNewWindowAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request newFrameName:(NSString *)frameName decisionListener:(id<WebPolicyDecisionListener>)listener
{
    NSURL *URL = actionInformation[WebActionOriginalURLKey];
    [[AppDelegate sharedDelegate] openURL:URL];
    [listener ignore];
}

#pragma mark - JavaScript Bridge

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
        NSImage *image = [wrapper image];
        if ([image isHiDPI]) {
            // for hidpi images we want to write an <img> tag instead of using markdown syntax, as this will prevent it from drawing too large.
            filename = [filename stringByReplacingOccurrencesOfString:@"'" withString:@"`"];
            CGSize size = image.size;
            // Workaround for realartists/shiphub-cocoa#241 Image attachments from Ship appear stretched / squished when viewed on github.com
            // Only include the image width, not the height so GitHub doesn't get confused.
            return [NSString stringWithFormat:@"<img src='%@' title='%@' width=%.0f>", linkURL, filename, size.width];
        } else {
            return [NSString stringWithFormat:@"![%@](%@)", filename, linkURL];
        }
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
            
            //DebugLog(@"%@", js);
            [self evaluateJavaScript:js];
            
            pendingUploads--;
            
            if (pendingUploads == 0) {
                js = [NSString stringWithFormat:@"pasteCallback(%@, 'completed')", handle];
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
    //DebugLog(@"%@", js);
    [self evaluateJavaScript:js];
}

- (void)selectAttachments:(NSNumber *)handle {
    NSOpenPanel* panel = [NSOpenPanel openPanel];
    
    panel.canChooseFiles = YES;
    panel.canChooseDirectories = NO;
    panel.allowsMultipleSelection = YES;
    
    [panel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton && panel.URLs.count > 0) {
            NSArray *wrappers = [panel.URLs arrayByMappingObjects:^id(id obj) {
                return [[NSFileWrapper alloc] initWithURL:obj options:0 error:NULL];
            }];
            
            [self pasteWrappers:wrappers handle:handle];
        } else {
            // cancel
            NSString *js = [NSString stringWithFormat:@"pasteCallback(%@, 'completed')", handle];
            [self evaluateJavaScript:js];
        }
    }];
}

- (void)pasteHelper:(NSDictionary *)msg {
    NSNumber *handle = msg[@"handle"];
    NSString *pasteboardName = msg[@"pasteboard"];
    
    NSPasteboard *pasteboard = nil;
    if ([pasteboardName isEqualToString:@"dragging"]) {
        pasteboard = [NSPasteboard pasteboardWithName:_web.dragPasteboardName?:NSDragPboard];
    } else if ([pasteboardName isEqualToString:@"NSOpenPanel"]) {
        [self selectAttachments:handle];
    } else {
        pasteboard = [NSPasteboard generalPasteboard];
    }
    
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
                        js = [NSString stringWithFormat:@"pasteCallback(%@, 'completed')", handle];
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

- (void)spellcheck:(NSDictionary *)msg {
    NSSpellChecker *checker = [NSSpellChecker sharedSpellChecker];
    if (_spellcheckDocumentTag == 0) {
        _spellcheckDocumentTag = [NSSpellChecker uniqueSpellDocumentTag];
    }
    
    if (msg[@"contextMenu"]) {
        _spellcheckContextTarget = msg[@"target"];
        return;
    }
    
    NSString *text = msg[@"text"];
    NSNumber *handle = msg[@"handle"];
    [checker requestCheckingOfString:text range:NSMakeRange(0, text.length) types:NSTextCheckingTypeSpelling options:nil inSpellDocumentWithTag:_spellcheckDocumentTag completionHandler:^(NSInteger sequenceNumber, NSArray<NSTextCheckingResult *> * _Nonnull results, NSOrthography * _Nonnull orthography, NSInteger wordCount) {
        
        // convert NSTextCheckingResults to {start:{line, ch}, end:{line, ch}} objects
        
        NSMutableArray *cmRanges = [NSMutableArray new];
        
        __block NSUInteger processed = 0;
        __block NSUInteger line = 0;
        
        [text enumerateSubstringsInRange:NSMakeRange(0, text.length) options:NSStringEnumerationByLines usingBlock:^(NSString * _Nullable substring, NSRange substringRange, NSRange enclosingRange, BOOL * _Nonnull stop) {
            
            for (NSUInteger i = processed; i < results.count; i++) {
                NSTextCheckingResult *result = results[i];
                NSRange r = result.range;
                if (NSRangeContainsRange(substringRange, r)) {
                    NSDictionary *cmRange = @{ @"start": @{ @"line" : @(line), @"ch" : @(r.location - substringRange.location) },
                                               @"end": @{ @"line": @(line), @"ch" : @(NSMaxRange(r) - substringRange.location) } };
                    [cmRanges addObject:cmRange];
                    processed++;
                } else if (NSMaxRange(substringRange) < NSMaxRange(r)) {
                    break;
                }
            }
            
            line++;
            *stop = processed == results.count;
            
        }];
        
        RunOnMain(^{
            NSString *callback = [NSString stringWithFormat:@"window.spellcheckResults({handle:%@, results:%@});", handle, [JSON stringifyObject:cmRanges]];
            [self evaluateJavaScript:callback];
        });
        
    }];
}

- (void)loadCodeSnippet:(NSDictionary *)msg {
    NSString *repo = msg[@"repoFullName"];
    NSString *sha = msg[@"sha"];
    NSString *path = msg[@"path"];
    NSInteger startLine = [msg[@"startLine"] integerValue];
    NSInteger endLine = [msg[@"endLine"] integerValue];
    NSNumber *handle = msg[@"handle"];
    
    CodeSnippetKey *key = [CodeSnippetKey keyWithRepoFullName:repo sha:sha path:path startLine:startLine endLine:endLine];
    
    [[CodeSnippetManager sharedManager] loadSnippet:key completion:^(NSString *snippet, NSError *error) {
        RunOnMain(^{
            NSMutableDictionary *result = [NSMutableDictionary new];
            result[@"handle"] = handle;
            if (snippet) {
                result[@"snippet"] = snippet;
            }
            if (error) {
                result[@"error"] = [error localizedDescription];
            }
            
            [self evaluateJavaScript:[NSString stringWithFormat:@"window.loadCodeSnippetResult(%@)", [JSON stringifyObject:result]]];
        });
    }];
}

@end

@implementation IssueWebView

- (BOOL)performKeyEquivalent:(NSEvent *)event {
    // realartists/shiphub-cocoa#272 Ctrl-Tab to go between tabs doesn’t work for IssueDocuments
    if ((event.modifierFlags & NSControlKeyMask) != 0 && [event isTabKey]) {
        return NO;
    }
    return [super performKeyEquivalent:event];
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    self.dragPasteboardName = [[sender draggingPasteboard] name];
    return [super performDragOperation:sender];
}

@end

/* 
 realartists/shiphub-cocoa#352 Adding emojis from the popover style emoji picker doesn't work
 
 This is some real nasty swizzling to work around a WebKitLegacy bug.
 From interrogation with the debugger, I learned two things:
 
 1. The popover style emoji picker sends attributed strings with
    NSTextInputReplacementRangeAttributeName.
 
    This doesn't seem to affect anything that WebKit does, but it
    is a way to tell the difference between the popover picker
    and the panel picker
 
 2. If insertText is called while the WebView isn't the key view,
    it will drop the insertion on the floor. When the popover emoji
    picker is in front, it (or more accurately, its search field) is
    the the key view.
 
 The trick is to delay insertText: a moment when using the popover
 emoji picker, long enough for the popover to dismiss and the key
 view to return to the WebView.
*/
@interface NSObject (FixWebViewInputText)

- (void)ship_fixInsertText:(NSAttributedString *)str;

@end

static void fixWebViewInputText(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = NSClassFromString(@"WebHTMLView");
        
        SEL originalSelector = NSSelectorFromString(@"insertText:");
        SEL swizzledSelector = @selector(ship_fixInsertText:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod =
        class_addMethod(class,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

@implementation NSObject (FixWebViewInputText)

- (void)ship_fixInsertText:(id)str {
    static NSString *const replRangeAttr = @"NSTextInputReplacementRangeAttributeName";
    NSRange range;
    if ([str isKindOfClass:[NSAttributedString class]] && [str attribute:replRangeAttr atIndex:0 effectiveRange:&range]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self ship_fixInsertText:str];
        });
    } else {
        [self ship_fixInsertText:str];
    }
}

@end

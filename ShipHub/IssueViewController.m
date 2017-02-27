//
//  IssueViewController.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueViewController.h"
#import "IssueWebControllerInternal.h"

#import "Analytics.h"
#import "AppDelegate.h"
#import "APIProxy.h"
#import "AttachmentManager.h"
#import "Auth.h"
#import "DataStore.h"
#import "EmptyLabelView.h"
#import "Error.h"
#import "Extras.h"
#import "MetadataStore.h"
#import "NSFileWrapper+ImageExtras.h"
#import "Issue.h"
#import "IssueDocumentController.h"
#import "IssueIdentifier.h"
#import "NewLabelController.h"
#import "NewMilestoneController.h"
#import "JSON.h"
#import "UpNextHelper.h"
#import "Account.h"
#import "WebKitExtras.h"

#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

typedef void (^SaveCompletion)(NSError *error);

NSString *const IssueViewControllerNeedsSaveDidChangeNotification = @"IssueViewControllerNeedsSaveDidChange";
NSString *const IssueViewControllerNeedsSaveKey = @"IssueViewControllerNeedsSave";

// touchbar identifiers
static NSString *const TBMarkdownItemId = @"TBMarkdown";
static NSString *const TBTextItemsId = @"TBText";
static NSString *const TBListItemsId = @"TBList";
static NSString *const TBHeadingItemsId = @"TBHeading";
static NSString *const TBTableItemId = @"TBTable";
static NSString *const TBLinkItemsId = @"TBLinks";
static NSString *const TBRuleItemId = @"TBRule";
static NSString *const TBCodeItemsId = @"TBCodes";
static NSString *const TBQuoteItemsId = @"TBQuotes";

@interface IssueViewController () <NSTouchBarDelegate> {
    NSMutableDictionary *_saveCompletions;
    NSTimer *_needsSaveTimer;
    
    CFAbsoluteTime _lastCheckedForUpdates;
    NSString *_lastStateJSON;
    
    NSString *_commentFocusKey;
}

@property NSTimer *markAsReadTimer;

@property (nonatomic, getter=hasCommentFocus) BOOL commentFocus;

@property NSTouchBar *markdownTouchBar;

@end

@implementation IssueViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setCommentFocus:(BOOL)commentFocus {
    if (_commentFocus != commentFocus) {
        _commentFocus = commentFocus;
        
        // update touch bar
        if ([self respondsToSelector:@selector(setTouchBar:)]) {
            self.touchBar = nil;
        }
    }
}

- (NSTouchBar *)makeTouchBar {
    if (!_commentFocus) {
        return nil;
    }
    
    if (!_markdownTouchBar) {
        _markdownTouchBar = [NSTouchBar new];
        _markdownTouchBar.customizationIdentifier = @"md";
        _markdownTouchBar.delegate = self;
        
        _markdownTouchBar.defaultItemIdentifiers = @[TBMarkdownItemId, NSTouchBarItemIdentifierOtherItemsProxy];
    }
    
    return _markdownTouchBar;
}

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if ([identifier isEqualToString:TBMarkdownItemId]) {
        NSPopoverTouchBarItem *pop = [[NSPopoverTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *icon = [NSImage imageNamed:@"MarkdownTBIcon"];
        icon.template = YES;
        pop.collapsedRepresentationImage = icon;
        
        NSTouchBar *popBar = [NSTouchBar new];
        popBar.delegate = self;
        popBar.customizationIdentifier = @"mditems";
        popBar.delegate = self;
        
        popBar.defaultItemIdentifiers = @[TBTextItemsId, TBListItemsId, TBTableItemId, TBLinkItemsId, TBCodeItemsId, TBQuoteItemsId];
        
        pop.popoverTouchBar = popBar;
        
        return pop;
    } else if ([identifier isEqualToString:TBTextItemsId]) {
        NSImage *bold = [NSImage imageNamed:NSImageNameTouchBarTextBoldTemplate];
        NSImage *italic = [NSImage imageNamed:NSImageNameTouchBarTextItalicTemplate];
        NSImage *strike = [NSImage imageNamed:NSImageNameTouchBarTextStrikethroughTemplate];
        bold.template = italic.template = strike.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[bold, italic, strike] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbText:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBListItemsId]) {
        NSImage *ulImage = [NSImage imageNamed:NSImageNameTouchBarTextListTemplate];
        NSImage *olImage = [NSImage imageNamed:@"MarkdownTBOrderedList"];
        NSImage *taskLImage = [NSImage imageNamed:@"MarkdownTBTaskList"];
        ulImage.template = olImage.template = taskLImage.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[ulImage, olImage, taskLImage] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbList:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBHeadingItemsId]) {
        NSImage *headingInc = [NSImage imageNamed:@"MarkdownTBHeadingIncrease"];
        NSImage *headingDec = [NSImage imageNamed:@"MarkdownTBHeadingDecrease"];
        headingInc.template = headingDec.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[headingInc, headingDec] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbHeading:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBTableItemId]) {
        NSImage *table = [NSImage imageNamed:@"MarkdownTBTable"];
        //NSImage *rule = [NSImage imageNamed:@"MarkdownTBRule"];
        table.template = YES;
        // rule.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[table/*, rule*/] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbTableRule:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBLinkItemsId]) {
        //NSImage *image = [NSImage imageNamed:@"MarkdownTBImage"];
        NSImage *link = [NSImage imageNamed:@"MarkdownTBHyperlink"];
        //image.template = YES;
        link.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[/*image, */link] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbLink:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBCodeItemsId]) {
        NSImage *inLine = [NSImage imageNamed:@"MarkdownTBCodeInline"];
        NSImage *block = [NSImage imageNamed:@"MarkdownTBCodeBlock"];
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[inLine, block] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbCode:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBQuoteItemsId]) {
        NSImage *inc = [NSImage imageNamed:@"MarkdownTBQuoteMore"];
        NSImage *dec = [NSImage imageNamed:@"MarkdownTBQuoteLess"];
        inc.template = dec.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[inc, dec] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbQuote:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    }
    
    return nil;
}

- (IBAction)scrollPageUp:(id)sender {
    [self.web.mainFrame.frameView scrollPageUp:sender];
}

- (IBAction)scrollPageDown:(id)sender {
    [self.web.mainFrame.frameView scrollPageDown:sender];
}

- (NSString *)webResourcePath {
    return @"IssueWeb";
}

- (NSString *)webHtmlFilename {
    return @"issue.html";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(issueDidUpdate:) name:DataStoreDidUpdateProblemsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyWindowDidChange:) name:NSWindowDidBecomeKeyNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataDidUpdate:) name:DataStoreDidUpdateMetadataNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewDidChange:) name:WebViewDidChangeNotification object:self.web];
}

- (void)configureNewIssue {
    [self evaluateJavaScript:@"configureNewIssue();"];
    self.web.hidden = NO;
    self.nothingLabel.hidden = YES;
    [[Analytics sharedInstance] track:@"New Issue"];
}

- (NSString *)issueStateJSON:(Issue *)issue {
    MetadataStore *meta = [[DataStore activeStore] metadataStore];
    
    NSMutableDictionary *state = [NSMutableDictionary new];
    state[@"issue"] = issue;
    
    state[@"me"] = [Account me];
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
    [self setIssue:issue scrollToCommentWithIdentifier:nil];
}

- (void)setIssue:(Issue *)issue scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier {
    dispatch_assert_current_queue(dispatch_get_main_queue());
    //DebugLog(@"%@", issue);
    BOOL identifierChanged = ![NSObject object:_issue.fullIdentifier isEqual:issue.fullIdentifier];
    BOOL shouldScrollToTop = issue != nil && _issue != nil && identifierChanged;
    _issue = issue;
    if (issue) {
        NSString *issueJSON = [self issueStateJSON:issue];
        _lastStateJSON = issueJSON;
        NSString *js = [NSString stringWithFormat:@"applyIssueState(%@, %@)", issueJSON, commentIdentifier];
        //DebugLog(@"%@", js);
        [self evaluateJavaScript:js];
        if (shouldScrollToTop && !commentIdentifier) {
            [self evaluateJavaScript:@"window.scroll(0, 0)"];
        }
    }
    [self updateTitle];
    BOOL hidden = _issue == nil;

    self.web.hidden = hidden;
    self.nothingLabel.hidden = !hidden;
    
    if (issue && identifierChanged) {
        [[Analytics sharedInstance] track:@"View Issue"];
    }
}

- (void)scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier {
    NSString *js = [NSString stringWithFormat:@"scrollToCommentWithIdentifier(%@)", [JSON stringifyObject:commentIdentifier]];
    [self evaluateJavaScript:js];
}

- (void)noteCheckedForIssueUpdates {
    _lastCheckedForUpdates = CFAbsoluteTimeGetCurrent();
}

- (void)checkForIssueUpdates {
    if (_issue.fullIdentifier) {
        [self noteCheckedForIssueUpdates];
        [[DataStore activeStore] checkForIssueUpdates:_issue.fullIdentifier];
    }
}

- (void)keyWindowDidChange:(NSNotification *)note {
    if ([self.view.window isKeyWindow]) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        if (now - _lastCheckedForUpdates > 30.0) {
            [self checkForIssueUpdates];
        }
        [self scheduleMarkAsReadTimerIfNeeded];
    }
}

- (void)setColumnBrowser:(BOOL)columnBrowser {
    _columnBrowser = columnBrowser;
    
    [self evaluateJavaScript:
     [NSString stringWithFormat:
      @"window.setInColumnBrowser(%@)",
      (_columnBrowser ? @"true" : @"false")]];
}

- (void)markAsReadTimerFired:(NSTimer *)timer {
    _markAsReadTimer = nil;
    if ([_issue.fullIdentifier isEqualToString:timer.userInfo] && _issue.unread) {
        NSWindow *window = self.view.window;
        if ([window isKeyWindow]) {
            [[DataStore activeStore] markIssueAsRead:timer.userInfo];
        }
    }
}

- (void)scheduleMarkAsReadTimerIfNeeded {
    if (!_issue) {
        [_markAsReadTimer invalidate];
        _markAsReadTimer = nil;
        return;
    }
    if (_markAsReadTimer && ![_markAsReadTimer.userInfo isEqualToString:_issue.fullIdentifier]) {
        [_markAsReadTimer invalidate];
        _markAsReadTimer = nil;
    }
    if (_issue.unread && !_markAsReadTimer) {
        _markAsReadTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 weakTarget:self selector:@selector(markAsReadTimerFired:) userInfo:_issue.fullIdentifier repeats:NO];
    }
}

- (void)issueDidUpdate:(NSNotification *)note {
    if (!_issue) return;
    if ([note object] == [DataStore activeStore]) {
        NSArray *updated = note.userInfo[DataStoreUpdatedProblemsKey];
        if ([updated containsObject:_issue.fullIdentifier]) {
            [[DataStore activeStore] loadFullIssue:_issue.fullIdentifier completion:^(Issue *issue, NSError *error) {
                if (issue) {
                    self.issue = issue;
                    [self scheduleMarkAsReadTimerIfNeeded];
                }
            }];
        }
    }
}

- (void)metadataDidUpdate:(NSNotification *)note {
    if (_issue.fullIdentifier && [note object] == [DataStore activeStore]) {
        NSString *json = [self issueStateJSON:_issue];
        if (![json isEqualToString:_lastStateJSON]) {
            DebugLog(@"issueStateJSON changed, reloading");
            [[DataStore activeStore] loadFullIssue:_issue.fullIdentifier completion:^(Issue *issue, NSError *error) {
                if ([issue.fullIdentifier isEqualToString:_issue.fullIdentifier]) {
                    self.issue = issue;
                }
            }];
        }
    }
}

- (void)registerJavaScriptAPI:(WebScriptObject *)windowObject {
    __weak __typeof(self) weakSelf = self;
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf proxyAPI:msg];
    } name:@"inAppAPI"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf scheduleNeedsSaveTimer];
    } name:@"documentEditedHelper"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf handleDocumentSaved:msg];
    } name:@"documentSaveHandler"];
    
    [[windowObject JSValue] setValue:^(NSString *name, NSArray *allLabels, NSString *owner, NSString *repo, JSValue *completionCallback){
        [weakSelf handleNewLabelWithName:name allLabels:allLabels owner:owner repo:repo completionCallback:(JSValue *)completionCallback];
    } forProperty:@"newLabel"];
    
    [[windowObject JSValue] setValue:^(NSString *name, NSString *owner, NSString *repo, JSValue *completionCallback){
        [weakSelf handleNewMilestoneWithName:name owner:owner repo:repo completionCallback:completionCallback];
    } forProperty:@"newMilestone"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf handleCommentFocus:msg];
    } name:@"inAppCommentFocus"];

    NSString *setupJS =
    @"window.inApp = true;\n"
    @"window.postAppMessage = function(msg) { window.inAppAPI.postMessage(msg); }\n";
    
    NSString *apiToken = [[[DataStore activeStore] auth] ghToken];
    setupJS = [setupJS stringByAppendingFormat:@"window.setAPIToken(\"%@\");\n", apiToken];
    
    [windowObject evaluateWebScript:setupJS];
}

- (void)reconfigureForReload {
    if (_issue) {
        [self setIssue:_issue];
        [self reload:nil];
    } else {
        [self configureNewIssue];
    }
}

#pragma mark WebView Notifications

- (void)needsSaveTimerFired:(NSNotification *)note {
    _needsSaveTimer = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:IssueViewControllerNeedsSaveDidChangeNotification object:self userInfo:@{ IssueViewControllerNeedsSaveKey : @([self needsSave]) }];
}

- (void)scheduleNeedsSaveTimer {
    if (!_needsSaveTimer) {
        _needsSaveTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(needsSaveTimerFired:) userInfo:nil repeats:NO];
    }
}

- (void)webViewDidChange:(NSNotification *)note {
    [self scheduleNeedsSaveTimer];
}

#pragma mark - Javascript Bridge

- (void)proxyAPI:(NSDictionary *)msg {
    //DebugLog(@"%@", msg);
    
    APIProxy *proxy = [APIProxy proxyWithRequest:msg completion:^(NSString *jsonResult, NSError *err) {
        dispatch_assert_current_queue(dispatch_get_main_queue());
        
        if (err) {
            BOOL isMutation = ![msg[@"opts"][@"method"] isEqualToString:@"GET"];
            
            if (isMutation) {
                NSAlert *alert = [NSAlert new];
                alert.alertStyle = NSCriticalAlertStyle;
                alert.messageText = NSLocalizedString(@"Unable to save issue", nil);
                alert.informativeText = [err localizedDescription] ?: @"";
                [alert addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
                [alert addButtonWithTitle:NSLocalizedString(@"Discard Changes", nil)];
                
                [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
                    if (returnCode == NSAlertFirstButtonReturn) {
                        [self proxyAPI:msg];
                    } else {
                        NSString *callback;
                        callback = [NSString stringWithFormat:@"apiCallback(%@, null, %@)", msg[@"handle"], [JSON stringifyObject:[err localizedDescription]]];
                        [self evaluateJavaScript:callback];
                        [self revert:nil];
                    }
                }];
            } else {
                NSString *callback;
                callback = [NSString stringWithFormat:@"apiCallback(%@, null, %@)", msg[@"handle"], [JSON stringifyObject:[err localizedDescription]]];
                [self evaluateJavaScript:callback];
            }
        } else {
            NSString *callback = [NSString stringWithFormat:@"apiCallback(%@, %@, null)", msg[@"handle"], jsonResult];
            [self evaluateJavaScript:callback];
        }
    }];
    [proxy setUpdatedIssueHandler:^(Issue *updatedIssue) {
        if (_issue.fullIdentifier == nil || [_issue.fullIdentifier isEqualToString:updatedIssue.fullIdentifier]) {
            _issue = updatedIssue;
            [self updateTitle];
            [self scheduleNeedsSaveTimer];
        }
    }];
    [proxy resume];
}

- (void)handleDocumentSaved:(NSDictionary *)msg {
    NSNumber *token = msg[@"token"];
    if (token) {
        SaveCompletion completion = _saveCompletions[token];
        if (completion) {
            [_saveCompletions removeObjectForKey:token];
            
            id err = msg[@"error"];
            NSError *error = nil;
            if (err && err != [NSNull null]) {
                error = [NSError shipErrorWithCode:ShipErrorCodeProblemSaveOtherError localizedMessage:err];
            }
            completion(error);
        }
    }
}

- (void)handleNewLabelWithName:(NSString *)name
                     allLabels:(NSArray *)allLabels
                         owner:(NSString *)owner
                          repo:(NSString *)repo
            completionCallback:(JSValue *)completionCallback {
    NewLabelController *newLabelController = [[NewLabelController alloc] initWithPrefilledName:(name ?: @"")
                                                                                     allLabels:allLabels
                                                                                         owner:owner
                                                                                          repo:repo];
    
    [self.view.window beginSheet:newLabelController.window completionHandler:^(NSModalResponse response){
        if (response == NSModalResponseOK) {
            NSAssert(newLabelController.createdLabel != nil, @"succeeded but created label was nil");
            [completionCallback callWithArguments:@[@YES, newLabelController.createdLabel]];
        } else {
            [completionCallback callWithArguments:@[@NO]];
        }
    }];
}

- (void)handleNewMilestoneWithName:(NSString *)name owner:(NSString *)owner repo:(NSString *)repoName completionCallback:(JSValue *)completionCallback
{
    Repo *repo = [[[[[DataStore activeStore] metadataStore] activeRepos] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"fullName = %@", [NSString stringWithFormat:@"%@/%@", owner, repoName]] limit:1] firstObject];
    if (!repo) {
        [completionCallback callWithArguments:@[]];
        return;
    }
    
    NewMilestoneController *mc = [[NewMilestoneController alloc] initWithInitialRepos:@[repo] initialReposAreRequired:YES initialName:name];
    [mc beginInWindow:self.view.window completion:^(NSArray<Milestone *> *createdMilestones, NSError *error) {
        if (error) {
            [completionCallback callWithArguments:@[]];
        } else {
            id jsRepr = [JSON JSRepresentableValueFromSerializedObject:createdMilestones withNameTransformer:[JSON underbarsAndIDNameTransformer]];
            [completionCallback callWithArguments:@[jsRepr]];
        }
    }];
}

- (void)handleCommentFocus:(NSDictionary *)d {
    NSString *key = d[@"key"];
    BOOL state = [d[@"state"] boolValue];
    
    if (!state && (!_commentFocusKey || [_commentFocusKey isEqualToString:key])) {
        // blurred
        self.commentFocus = NO;
    } else if (state) {
        _commentFocusKey = [key copy];
        self.commentFocus = YES;
    }
}

#pragma mark -

- (IBAction)reload:(id)sender {
    if (_issue.fullIdentifier) {
        [[DataStore activeStore] checkForIssueUpdates:_issue.fullIdentifier];
    }
}

- (IBAction)revert:(id)sender {
    if (_issue) {
        self.issue = _issue;
    } else {
        [self configureNewIssue];
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

- (IBAction)toggleUpNext:(id)sender {
    [[UpNextHelper sharedHelper] addToUpNext:@[_issue.fullIdentifier] atHead:NO window:self.view.window completion:nil];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(saveDocument:)) {
        return [self needsSave];
    } else if (menuItem.action == @selector(fixSpelling:)) {
        return menuItem.representedObject != nil;
    } else if (menuItem.action == @selector(toggleUpNext:)) {
        menuItem.title = NSLocalizedString(@"Add to Up Next", nil);
    } else if ([NSStringFromSelector(menuItem.action) hasPrefix:@"md"]) {
        return YES; // return _commentFocus;
    } else if (menuItem.action == @selector(toggleCommentPreview:)) {
        return YES;
    }
    return _issue.fullIdentifier != nil;
}

- (IBAction)openDocumentInBrowser:(id)sender {
    NSURL *URL = [[_issue fullIdentifier] issueGitHubURL];
    [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (BOOL)needsSave {
    JSValue *val = [self.web.mainFrame.javaScriptContext evaluateScript:@"window.needsSave()"];
    return [val toBool];
}

- (IBAction)saveDocument:(id)sender {
    [self saveWithCompletion:nil];
}

- (void)saveWithCompletion:(void (^)(NSError *err))completion {
    static NSInteger token = 1;
    ++token;
    
    if (completion) {
        if (!_saveCompletions) {
            _saveCompletions = [NSMutableDictionary new];
        }
        _saveCompletions[@(token)] = [completion copy];
    }
    
    [self.web.mainFrame.javaScriptContext evaluateScript:[NSString stringWithFormat:@"window.save(%td);", token]];
}

#pragma mark - Formatting Controls

- (void)applyFormat:(NSString *)format {
    [self evaluateJavaScript:[NSString stringWithFormat:@"applyMarkdownFormat(%@)", [JSON stringifyObject:format withNameTransformer:nil]]];
}

- (IBAction)mdBold:(id)sender {
    [self applyFormat:@"bold"];
}

- (IBAction)mdItalic:(id)sender {
    [self applyFormat:@"italic"];
}

- (IBAction)mdStrike:(id)sender {
    [self applyFormat:@"strike"];
}

- (IBAction)mdIncreaseHeading:(id)sender {
    [self applyFormat:@"headingMore"];
}

- (IBAction)mdDecreaseHeading:(id)sender {
    [self applyFormat:@"headingLess"];
}

- (IBAction)mdUnorderedList:(id)sender {
    [self applyFormat:@"insertUL"];
}

- (IBAction)mdOrderedList:(id)sender {
    [self applyFormat:@"insertOL"];
}

- (IBAction)mdTaskList:(id)sender {
    [self applyFormat:@"insertTaskList"];
}

- (IBAction)mdTable:(id)sender {
    [self applyFormat:@"insertTable"];
}

- (IBAction)mdHorizontalRule:(id)sender {
    [self applyFormat:@"insertHorizontalRule"];
}

- (IBAction)mdCodeBlock:(id)sender {
    [self applyFormat:@"code"];
}

- (IBAction)mdCodeFence:(id)sender {
    [self applyFormat:@"codefence"];
}

- (IBAction)mdHyperlink:(id)sender {
    [self applyFormat:@"hyperlink"];
}

- (IBAction)mdAttachFile:(id)sender {
    [self applyFormat:@"attach"];
}

- (IBAction)mdIncreaseQuote:(id)sender {
    [self applyFormat:@"quoteMore"];
}

- (IBAction)mdDecreaseQuote:(id)sender {
    [self applyFormat:@"quoteLess"];
}

- (IBAction)mdIndent:(id)sender {
    [self applyFormat:@"indentMore"];
}

- (IBAction)mdOutdent:(id)sender {
    [self applyFormat:@"indentLess"];
}

- (IBAction)mdTbText:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdBold:nil]; break;
        case 1: [self mdItalic:nil]; break;
        case 2: [self mdStrike:nil]; break;
    }
}

- (IBAction)mdTbList:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdUnorderedList:nil]; break;
        case 1: [self mdOrderedList:nil]; break;
        case 2: [self mdTaskList:nil]; break;
    }
}

- (IBAction)mdTbHeading:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdIncreaseHeading:nil]; break;
        case 1: [self mdDecreaseHeading:nil]; break;
    }
}

- (IBAction)mdTbTableRule:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdTable:nil]; break;
        case 1: [self mdHorizontalRule:nil]; break;
    }
}

- (IBAction)mdTbLink:(id)sender {
    [self mdAttachFile:nil];
}

- (IBAction)mdTbCode:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdCodeBlock:nil]; break;
        case 1: [self mdCodeFence:nil]; break;
    }
}

- (IBAction)mdTbQuote:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdIncreaseQuote:nil]; break;
        case 1: [self mdDecreaseQuote:nil]; break;
    }
}
                                                                                   
#pragma mark -

- (IBAction)toggleCommentPreview:(id)sender {
    [self evaluateJavaScript:@"toggleCommentPreview()"];
}

#pragma mark -

- (void)takeFocus {
    [self evaluateJavaScript:@"focusIssue()"];
}

@end

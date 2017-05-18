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
#import "MarkdownFormattingController.h"
#import "PRMergeViewController.h"
#import "ProgressSheet.h"
#import "TrackingProgressSheet.h"
#import "PRPostMergeController.h"
#import "PRReviewChangesViewController.h"
#import "PRReview.h"

#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>

typedef void (^SaveCompletion)(NSError *error);

NSString *const IssueViewControllerNeedsSaveDidChangeNotification = @"IssueViewControllerNeedsSaveDidChange";
NSString *const IssueViewControllerNeedsSaveKey = @"IssueViewControllerNeedsSave";


@interface IssueViewController () <MarkdownFormattingControllerDelegate, PRMergeViewControllerDelegate, PRReviewChangesViewControllerDelegate> {
    NSMutableDictionary *_saveCompletions;
    NSTimer *_needsSaveTimer;
    
    CFAbsoluteTime _lastCheckedForUpdates;
    NSString *_lastStateJSON;
}

@property NSTimer *markAsReadTimer;
@property IBOutlet MarkdownFormattingController *markdownFormattingController;

@property PRMergeViewController *mergeController;
@property NSPopover *mergePopover;

@property PRReviewChangesViewController *reviewChangesController;
@property NSPopover *reviewChangesPopover;

@end

@implementation IssueViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSTouchBar *)makeTouchBar {
    if (_markdownFormattingController.hasCommentFocus) {
        return _markdownFormattingController.markdownTouchBar;
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

- (void)loadView {
    _markdownFormattingController = [MarkdownFormattingController new];
    _markdownFormattingController.delegate = self;
    _markdownFormattingController.requireFocusToValidateActions = NO;
    
    _markdownFormattingController.nextResponder = self.nextResponder;
    [super setNextResponder:_markdownFormattingController];
    
    [super loadView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(issueDidUpdate:) name:DataStoreDidUpdateProblemsNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyWindowDidChange:) name:NSWindowDidBecomeKeyNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataDidUpdate:) name:DataStoreDidUpdateMetadataNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webViewDidChange:) name:WebViewDidChangeNotification object:self.web];
}

- (void)setNextResponder:(NSResponder *)nextResponder {
    if (_markdownFormattingController) {
        _markdownFormattingController.nextResponder = nextResponder;
    } else {
        [super setNextResponder:nextResponder];
    }
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
    [self scheduleNeedsSaveTimer];
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
        [weakSelf handleDiffViewer:msg];
    } name:@"diffViewer"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf handleMergePopover:msg];
    } name:@"mergePopover"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf handleEditConflicts:msg];
    } name:@"editConflicts"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf handleRevertMergeCommit:msg];
    } name:@"revertMergeCommit"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf handleSubmitPendingReview:msg];
    } name:@"submitPendingReview"];
    
    [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
        [weakSelf handleDeletePendingReview:msg];
    } name:@"deletePendingReview"];
    
    [_markdownFormattingController registerJavaScriptAPI:windowObject];

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

- (void)handleDiffViewer:(NSDictionary *)msg {
    IssueDocumentController *docController = [IssueDocumentController sharedDocumentController];
    NSDictionary *scrollInfo = msg[@"scrollInfo"];
    [docController openDiffWithIdentifier:self.issue.fullIdentifier canOpenExternally:NO scrollInfo:scrollInfo completion:nil];
}

- (void)handleEditConflicts:(NSDictionary *)msg {
    NSURL *URL = [[[self issue] fullIdentifier] pullRequestGitHubURL];
    URL = [URL URLByAppendingPathComponent:@"conflicts"];
    [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (void)handleRevertMergeCommit:(NSDictionary *)msg {
    Trace();
    
    NSString *commit = msg[@"commit"];
    
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Revert Pull Request?", nil);
    alert.informativeText = NSLocalizedString(@"This will create a new branch with a revert of the merge commit in it, and then will propose a new pull request to merge the revert back to the base branch", nil);
    
    [alert addButtonWithTitle:NSLocalizedString(@"Revert", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self revertMergeCommit:commit];
        }
    }];
}

- (void)revertMergeCommit:(NSString *)commit {
    TrackingProgressSheet *sheet = [TrackingProgressSheet new];
    [sheet beginSheetInWindow:self.view.window];
    
    PullRequest *pr = [[PullRequest alloc] initWithIssue:self.issue];
    
    sheet.progress = [pr revertMerge:commit withCompletion:^(Issue *prTemplate, NSError *error) {
        [sheet endSheet];
        
        if (error) {
            if (![error isCancelError]) {
                NSAlert *alert = [NSAlert new];
                alert.messageText = NSLocalizedString(@"Failed to create branch to revert merge commit", nil);
                alert.informativeText = [error localizedDescription];
                
                [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
                
                [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
            }
        } else {
            [[IssueDocumentController sharedDocumentController] newDocumentWithIssueTemplate:prTemplate];
        }
    }];
}

- (void)showPopover:(NSPopover *)popover relativeToDOMBBox:(NSDictionary *)bbox {
    CGRect r = CGRectMake([bbox[@"left"] doubleValue],
                          [bbox[@"top"] doubleValue],
                          [bbox[@"width"] doubleValue],
                          [bbox[@"height"] doubleValue]);
    
    NSView *docView = self.web.mainFrame.frameView.documentView;
    NSScrollView *scrollView = [docView enclosingScrollView];
    
    r = [docView convertRect:r toView:self.view];
    
    // sadly, WebView is dumb and doesn't account for scrolling in coordinate conversions.
    // sigh.
    r.origin.x -= scrollView.documentVisibleRect.origin.x;
    r.origin.y -= scrollView.documentVisibleRect.origin.y;
    
    [popover showRelativeToRect:r ofView:self.view preferredEdge:NSRectEdgeMinY];
}

- (PRReview *)existingPendingReview {
    PRReview *pendingReview = [self.issue.reviews firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"state = %ld", PRReviewStatePending]];
    return pendingReview;
}

- (void)handleSubmitPendingReview:(NSDictionary *)msg {
    NSDictionary *bbox = msg[@"bbox"];
    
    if (_reviewChangesPopover.shown) {
        [_reviewChangesPopover close];
        return;
    }
    
    PRReview *pendingReview = [self existingPendingReview];
    if (!pendingReview) return;
    
    if (!_reviewChangesController) {
        _reviewChangesController = [PRReviewChangesViewController new];
        _reviewChangesController.delegate = self;
    }
    
    _reviewChangesPopover = [[NSPopover alloc] init];
    _reviewChangesPopover.contentViewController = _reviewChangesController;
    _reviewChangesPopover.behavior = NSPopoverBehaviorSemitransient;
    
    PullRequest *pr = [[PullRequest alloc] initWithIssue:self.issue];
    _reviewChangesController.pr = pr;
    
    _reviewChangesController.numberOfPendingComments = pendingReview.comments.count;
    
    [self showPopover:_reviewChangesPopover relativeToDOMBBox:bbox];
}

- (void)handleDeletePendingReview:(NSDictionary *)msg {
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Delete Pending Review?", nil);
    alert.informativeText = NSLocalizedString(@"This will delete your pending review and all associated comments. This operation cannot be undone.", nil);
    
    [alert addButtonWithTitle:NSLocalizedString(@"Delete", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self deletePendingReview];
        }
    }];
}

- (void)deletePendingReview {
    PRReview *pending = [self existingPendingReview];
    if (pending) {
        ProgressSheet *progress = [ProgressSheet new];
        progress.message = NSLocalizedString(@"Deleting review", nil);
        [progress beginSheetInWindow:self.view.window];
        
        NSDictionary *info = @{ PRReviewDeletedInIssueIdentifierKey : self.issue.fullIdentifier };
        [[NSNotificationCenter defaultCenter] postNotificationName:PRReviewDeletedExplicitlyNotification object:info];
        
        [[DataStore activeStore] deletePendingReview:pending inIssue:self.issue.fullIdentifier completion:^(NSError *error) {
            [progress endSheet];
            if (error) {
                [self presentError:error withRetry:^{
                    [self deletePendingReview];
                } fail:nil];
            }
        }];
    }
}

- (void)handleMergePopover:(NSDictionary *)msg {
    NSDictionary *bbox = msg[@"bbox"];
    
    if (_mergePopover.shown) {
        [_mergePopover close];
        return;
    }
    
    if (!_mergeController) {
        _mergeController = [PRMergeViewController new];
        _mergeController.delegate = self;
    }
    if (![_mergeController.issue.fullIdentifier isEqualToString:self.issue.fullIdentifier]) {
        _mergeController.issue = self.issue;
    }

    _mergePopover = [[NSPopover alloc] init];
    _mergePopover.contentViewController = _mergeController;
    _mergePopover.behavior = NSPopoverBehaviorSemitransient;
    
    [self showPopover:_mergePopover relativeToDOMBBox:bbox];
}

#pragma mark - PRMergeViewControllerDelegate

- (void)mergeViewController:(PRMergeViewController *)vc didSubmitWithTitle:(NSString *)title message:(NSString *)message strategy:(PRMergeStrategy)strat
{
    [_mergePopover close];
    _mergePopover = nil;
    _mergeController = nil;
    
    ProgressSheet *progress = [ProgressSheet new];
    progress.message = NSLocalizedString(@"Merging", nil);
    [progress beginSheetInWindow:self.view.window];
    
    [[DataStore activeStore] mergePullRequest:self.issue.fullIdentifier strategy:strat title:title message:message completion:^(Issue *issue, NSError *error) {
        [progress endSheet];
        if (error) {
            [self presentError:error];
        } else {
            self.issue = issue;
            PRPostMergeController *postMerge = [PRPostMergeController new];
            postMerge.issue = issue;
            
            [postMerge beginSheetModalForWindow:self.view.window completion:nil];
        }
    }];
}

#pragma mark - PRReviewChangesViewControllerDelegate

- (void)reviewChangesViewController:(PRReviewChangesViewController *)vc submitReview:(PRReview *)review {
    [_reviewChangesPopover close];
    _reviewChangesPopover = nil;
    _reviewChangesController = nil;
    
    ProgressSheet *progress = [ProgressSheet new];
    progress.message = NSLocalizedString(@"Sending review", nil);
    [progress beginSheetInWindow:self.view.window];
    
    PRReview *existingPendingReview = [self existingPendingReview];
    review.comments = existingPendingReview.comments;
    if (existingPendingReview) {
        review.identifier = existingPendingReview.identifier;
    }
    [[DataStore activeStore] addReview:review inIssue:self.issue.fullIdentifier completion:^(PRReview *roundtrip, NSError *error) {
        [progress endSheet];
        if (error) {
            [self presentError:error withRetry:^{
                [self reviewChangesViewController:nil submitReview:review];
            } fail:nil];
        } // else DataStore will update the model and things will proceed as usual
    }];
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

#pragma mark -

- (void)takeFocus {
    [self evaluateJavaScript:@"focusIssue()"];
}

#pragma mark -

- (BOOL)presentError:(NSError *)error {
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSCriticalAlertStyle;
    alert.messageText = [error localizedDescription] ?: [error description] ?: @"";
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:nil];
    return YES;
}

- (void)presentError:(NSError *)error withRetry:(dispatch_block_t)retry fail:(dispatch_block_t)fail {
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSCriticalAlertStyle;
    alert.messageText = NSLocalizedString(@"Unable to save changes", nil);
    alert.informativeText = [error localizedDescription] ?: @"";
    [alert addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Discard Changes", nil)];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            if (retry) retry();
        } else {
            if (fail) fail();
        }
    }];
}

@end

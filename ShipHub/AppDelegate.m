//
//  AppDelegate.m
//  ShipHub
//
//  Created by James Howard on 2/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "AppDelegate.h"

#import "Analytics.h"
#import "Auth.h"
#import "AuthController.h"
#import "DataStore.h"
#import "Extras.h"
#import "PullRequest.h"
#import "IssueIdentifier.h"
#import "IssueDocumentController.h"
#import "OverviewController.h"
#import "Reachability.h"
#import "UserNotificationManager.h"
#import "SubscriptionController.h"
#import "TextViewController.h"
#import "WelcomeHelpController.h"
#import "PRDocument.h"

#import <HockeySDK/HockeySDK.h>
#import <Sparkle/Sparkle.h>

typedef NS_ENUM(NSInteger, AccountMenuAction) {
    AccountMenuActionLogout = 1,
    AccountMenuActionNewAccount = 2
};

@interface AppDelegate () <AuthControllerDelegate, BITHockeyManagerDelegate> {
    BOOL _authConfigured;
    BOOL _notificationsRegistered;
    Auth *_nextAuth;
    BOOL _didFinishLaunching;
    NSMutableArray *_pendingURLs;
    CFAbsoluteTime _lastRateLimitAlertShown;
}

@property (weak) IBOutlet NSWindow *window;

@property Auth *auth;
@property AuthController *authController;
@property SubscriptionController *subscriptionController;
@property (strong) NSWindowController *acknowledgementsController;

@property IBOutlet NSMenu *accountMenu;
@property IBOutlet NSMenuItem *pullRequestMenu;

@property (strong) IBOutlet NSMutableArray *overviewControllers;

@property (strong) WelcomeHelpController *welcomeController;

@end

@implementation AppDelegate

+ (instancetype)sharedDelegate {
    return (AppDelegate *)[NSApp delegate];
}

- (void)configureAuth {
    if (_authConfigured) {
        return;
    }
    
    AuthAccountPair *lastUsedAccount = [Auth lastUsedLogin];
    NSArray *allAccounts = [Auth allLogins];
    if (![allAccounts containsObject:lastUsedAccount]) {
        lastUsedAccount = nil;
    }
    if (lastUsedAccount) {
        _auth = [Auth authWithAccountPair:lastUsedAccount];
    }
    if (!_auth) {
        if ([allAccounts count] > 0) {
            _auth = [Auth authWithAccountPair:[allAccounts firstObject]];
        }
    }

    _authConfigured = YES;
}

- (void)registerForDataStoreNotifications {
    if (_notificationsRegistered)
        return;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authChanged:) name:AuthStateChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseIncompatible:) name:DataStoreCannotOpenDatabaseNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(protocolIncompatible:) name:DataStoreNeedsMandatorySoftwareUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverTooOld:) name:DataStoreNeedsUpdatedServerNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rateLimitChanged:) name:DataStoreRateLimitedDidChangeNotification object:nil];
    
    _notificationsRegistered = YES;
}

- (void)registerHockeyApp {
    [[BITHockeyManager sharedHockeyManager] configureWithIdentifier:@"97cf8174021b4944999c2d3814b42359"];
    [[BITHockeyManager sharedHockeyManager] setDelegate:self];
    [[BITHockeyManager sharedHockeyManager].crashManager setAutoSubmitCrashReport: YES];
#ifdef DEBUG
    [BITHockeyManager sharedHockeyManager].disableMetricsManager = YES;
#endif
    [[BITHockeyManager sharedHockeyManager] startManager];
}

- (NSString *)userNameForHockeyManager:(BITHockeyManager *)hockeyManager componentManager:(BITHockeyBaseManager *)componentManager
{
    return [Auth lastUsedLogin].login;
}

- (IBAction)showSendFeedback:(id)sender {
    [[[BITHockeyManager sharedHockeyManager] feedbackManager] showFeedbackWindow];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [[NSAppleEventManager sharedAppleEventManager]
     setEventHandler:self
     andSelector:@selector(handleURLEvent:withReplyEvent:)
     forEventClass:kInternetEventClass
     andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSString *alternateFeedURLString = [[NSUserDefaults standardUserDefaults] stringForKey:@"SUFeedURL"];
    if (alternateFeedURLString) {
        NSURL *alternateFeedURL = [NSURL URLWithString:alternateFeedURLString];
        if (alternateFeedURL) {
            [[SUUpdater sharedUpdater] setFeedURL:alternateFeedURL];
        } else {
            ErrLog(@"Invalid SUFeedURL in defaults: %@", alternateFeedURLString);
        }
    }
#if DEBUG
    [[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:NO];
#else
    [[SUUpdater sharedUpdater] setAutomaticallyChecksForUpdates:YES];
#endif
    
    [self registerHockeyApp];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePullRequestMenuVisibility) name:NSWindowDidBecomeKeyNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePullRequestMenuVisibility) name:NSApplicationDidBecomeActiveNotification object:nil];
    [self updatePullRequestMenuVisibility];
    
    _overviewControllers = [NSMutableArray array];
    _authController = [AuthController new];
    _authController.delegate = self;
    [self configureAuth];
    [self registerForDataStoreNotifications];
    [self rebuildAccountMenu];
    [self showAuthIfNeededAnimated:NO];
    [self configureDataStoreAndShowUI];
    [[UserNotificationManager sharedManager] applicationDidLaunch:notification]; // start handling local user notifications
    
    [NSApp setServicesProvider:self];
    
    _didFinishLaunching = YES;
    for (NSURL *URL in _pendingURLs) {
        [self handleURL:URL atAppLaunch:YES];
    }
    [_pendingURLs removeAllObjects];

    [[Analytics sharedInstance] track:@"Application Launched"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)sender {
    // Clicking dock icon shouldn't create a new problem. It should bring the viewer to front if there's nothing else being shown.
    if ([[DataStore activeStore] isValid]) {
        [self showOverviewController:nil];
    }
    return YES;
}

- (void)handleURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString* urlStr = [[event paramDescriptorForKeyword:keyDirectObject]
                        stringValue];
    NSURL *URL = [NSURL URLWithString:urlStr];
    
    if (!URL) return;
    
    if (!_didFinishLaunching) {
        if (!_pendingURLs) {
            _pendingURLs = [NSMutableArray new];
        }
        [_pendingURLs addObject:URL];
    } else {
        [self handleURL:URL atAppLaunch:NO];
    }
}

- (BOOL)handleURL:(NSURL *)URL atAppLaunch:(BOOL)atAppLaunch
{
    DebugLog(@"handleURL:%@", URL);
    
    if (!URL) return YES;
    
    if ([[URL scheme] isEqualToString:@"ship+github"]) {
        if ([[URL host] isEqualToString:@"issue"]) {
            NSString *path = [URL path];
            NSString *num = [URL fragment];
            NSString *identifier = [[path substringFromIndex:1] stringByAppendingFormat:@"#%@", num];
            [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:identifier waitForIt:atAppLaunch];
        } else if ([[URL host] isEqualToString:@"newissue"]) {
            [[IssueDocumentController sharedDocumentController] newDocumentWithURL:URL];
        } else if ([[URL host] isEqualToString:@"signup"]) {
            [_authController continueWithLaunchURL:URL];
        } else if ([[URL host] isEqualToString:@"open"]) {
            NSURLComponents *comps = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
            NSString *signup = [comps queryItemsDictionary][@"signup"];
            if ([signup isEqualToString:@"complete"]) {
                [_subscriptionController close];
                [self showOverviewController:nil];
            }
        }
        return YES;
    } else if ([[URL scheme] isEqualToString:@"https"]) {
        NSNumber *commentIdentifier = nil;
        NSNumber *reviewCommentIdentifier = nil;
        NSString *issueIdentifier = [NSString issueIdentifierWithGitHubURL:URL commentIdentifier:&commentIdentifier];
        NSString *diffIdentifier = [PullRequest issueIdentifierForGitHubFilesURL:URL commentIdentifier:&reviewCommentIdentifier];
        if (issueIdentifier) {
            [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:issueIdentifier canOpenExternally:YES scrollToCommentWithIdentifier:commentIdentifier completion:nil];
            return YES;
        } else if (diffIdentifier) {
            [[IssueDocumentController sharedDocumentController] openDiffWithIdentifier:diffIdentifier canOpenExternally:YES scrollToCommentWithIdentifier:reviewCommentIdentifier completion:nil];
            return YES;
        }
    }
    
    return NO;
}

- (void)openURL:(NSURL *)URL {
    BOOL handled = [self handleURL:URL atAppLaunch:NO];
    if (!handled) {
        [[NSWorkspace sharedWorkspace] openURL:URL];
    }
}

- (BOOL)openById:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSError **)error {
    if (![NSString canReadIssueIdentifiersFromPasteboard:pboard]) {
        return NO;
    }
    
    NSArray<NSString *> *identifiers = [NSString readIssueIdentifiersFromPasteboard:pboard];
    
    [[IssueDocumentController sharedDocumentController] openIssuesWithIdentifiers:identifiers];
    
    return YES;
}

- (void)updatePullRequestMenuVisibility {
    NSDocument *keyDocument = [[IssueDocumentController sharedDocumentController] currentDocument];
    _pullRequestMenu.hidden = ![keyDocument isKindOfClass:[PRDocument class]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(logout:)
        || menuItem.action == @selector(showOverviewController:)
        || menuItem.action == @selector(newOverviewController:)
        || menuItem.action == @selector(searchAllProblems:)
        || menuItem.action == @selector(showBilling:))
    {
        return _auth != nil && _auth.authState == AuthStateValid;
    }
    return YES;
}

- (void)migrationEnded:(NSNotification *)note {
    DataStore *store = [DataStore activeStore];
    if ([store isValid]) {
        [self showOverviewController:nil];
    }
}

- (void)willPurge:(NSNotification *)note {
#if !INCOMPLETE
    [[[ProblemDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(close)];
#endif
    [_overviewControllers makeObjectsPerformSelector:@selector(close)];
}

- (void)showAuthIfNeededAnimated:(BOOL)animated {
    if (_auth.authState != AuthStateValid) {
        [_authController showWindow:self];

        [[Analytics sharedInstance] track:@"Welcome Shown"];
    }
}

- (void)authChanged:(NSNotification *)note {
    if ([note object] == _auth) {
        [self rebuildAccountMenu];
        [self showAuthIfNeededAnimated:YES];
        if (_auth.authState == AuthStateInvalid) {
            [_overviewControllers makeObjectsPerformSelector:@selector(close)];
        }
    }
}

- (void)authController:(AuthController *)controller authenticated:(Auth *)auth {
    Trace();
    
    [controller close];
    self.auth = auth;
    
    [self configureDataStoreAndShowUI];
    [self rebuildAccountMenu];
    [self showWelcomeIfNeeded];
}

- (void)configureDataStoreAndShowUI {
    if (_auth && [[DataStore activeStore] auth] != _auth) {
        DataStore *store = [DataStore storeWithAuth:_auth];
        [store activate];
        
        [self showOverviewController:nil];
    }
}

- (IBAction)logout:(id)sender {
    [self changeAccount:sender];
}

- (void)rebuildAccountMenu {
    [_accountMenu removeAllItems];
    
    NSInteger added = 0;
    
    for (AuthAccountPair *login in [[Auth allLogins] reverseObjectEnumerator]) {
        BOOL isMe = [[_auth.account pair] isEqual:login];
        NSString *title = login.login;
        if (![login.shipHost isEqualToString:DefaultShipHost()]) {
            title = [NSString stringWithFormat:@"%@ [%@]", login.login, login.shipHost];
        }
        if (isMe) {
            title = [NSString stringWithFormat:NSLocalizedString(@"Logged in as %@", nil), title];
        }
        NSMenuItem *item = [_accountMenu insertItemWithTitle:title action:isMe?nil:@selector(changeAccount:) keyEquivalent:@"" atIndex:0];
        item.target = isMe?nil:self;
        item.representedObject = login;
        item.state = isMe ? NSOnState : NSOffState;
        added++;
    }
    
    if (added > 0) {
        [_accountMenu insertItem:[NSMenuItem separatorItem] atIndex:added];
        added++;
        NSMenuItem *item = [_accountMenu insertItemWithTitle:NSLocalizedString(@"Add new account", nil) action:@selector(changeAccount:) keyEquivalent:@"" atIndex:added];
        item.target = self;
        item.tag = AccountMenuActionNewAccount;
        item.representedObject = nil;
        added++;
    }
    
    if ([_auth.account.login length] && _auth.authState == AuthStateValid) {
        _accountMenu.title = _auth.account.login;
        
        [_accountMenu insertItem:[NSMenuItem separatorItem] atIndex:added];
        added++;
        NSMenuItem *item = [_accountMenu insertItemWithTitle:NSLocalizedString(@"Logout", nil) action:@selector(logout:) keyEquivalent:@"" atIndex:added];
        item.target = self;
        item.tag = AccountMenuActionLogout;
        item.representedObject = nil;
        added++;
        
    } else {
        _accountMenu.title = NSLocalizedString(@"Account", nil);
    }
}

- (void)documentController:(NSDocumentController *)documentController
didCloseAllForAccountChange:(BOOL)didCloseAll
               contextInfo:(void *)contextInfo {
    if (_nextAuth) {
        [self authController:nil authenticated:_nextAuth];
        _nextAuth = nil;
    } else {
        _auth = nil;
        [[DataStore activeStore] deactivate];
        [self showAuthIfNeededAnimated:YES];
    }
    [self rebuildAccountMenu];
}

- (IBAction)changeAccount:(id)sender {
    AuthAccountPair *login = [sender representedObject];
    if (login && [login isEqual:[_auth.account pair]]) {
        return;
    }
    
    if (!login && !_auth.account.login) {
        [self showAuthIfNeededAnimated:YES];
        return;
    }
    
    BOOL logout = login == nil && [sender tag] == AccountMenuActionLogout;
    BOOL addNew = login == nil && [sender tag] == AccountMenuActionNewAccount;
    
    dispatch_block_t changeBlock = ^{
        if (addNew) {
            [[Analytics sharedInstance] track:@"Add new account"];
        }

        if (login) {
            _nextAuth = [Auth authWithAccountPair:login];
        } else if (logout) {
            [_auth logout];
            [[Analytics sharedInstance] track:@"Logout"];
            [[Analytics sharedInstance] flush];
            _nextAuth = nil;
        } else if (addNew) {
            _nextAuth = nil;
        }
        
        [_authController close];
        [_subscriptionController close];
        [_overviewControllers makeObjectsPerformSelector:@selector(close)];
        
        IssueDocumentController *docController = [IssueDocumentController sharedDocumentController];
        [docController closeAllDocumentsWithDelegate:self
                                 didCloseAllSelector:@selector(documentController:didCloseAllForAccountChange:contextInfo:)
                                         contextInfo:NULL];
    };
    
    if (_auth.authState == AuthStateValid) {
        NSAlert *alert = [[NSAlert alloc] init];
        if (login) {
            NSString *loginName = login.login;
            if (![login.shipHost isEqualToString:DefaultShipHost()]) {
                loginName = [NSString stringWithFormat:@"%@ [%@]", loginName, login.shipHost];
            }
            alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Logout and change account to %@?", nil), loginName];
            alert.informativeText = NSLocalizedString(@"Changing accounts will close all open issues.", nil);
            [alert addButtonWithTitle:NSLocalizedString(@"Change Account", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        } else if (logout) {
            alert.messageText = NSLocalizedString(@"Are you sure you want to logout?", nil);
            alert.informativeText = NSLocalizedString(@"Logging out will deauthorize your access to Ship on all of your computers.\n\nAdditionally, it will deactivate server integration for Ship, including removing any installed GitHub webhooks for your repositories, provided you are the only Ship user for the repositories.", nil);
            [alert addButtonWithTitle:NSLocalizedString(@"Logout", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        } else /* addNew */ {
            alert.messageText = NSLocalizedString(@"Are you sure you want to change to a new account?", nil);
            alert.informativeText = NSLocalizedString(@"Changing accounts will close all open issues.", nil);
            [alert addButtonWithTitle:NSLocalizedString(@"Change Account", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        }
        
        if (NSAlertFirstButtonReturn == [alert runModal]) {
            changeBlock();
        }
    } else {
        changeBlock();
    }
}

- (OverviewController *)activeOverviewController {
    id activeDelegate = [[NSApp mainWindow] delegate];
    if ([activeDelegate isKindOfClass:[OverviewController class]]) {
        return activeDelegate;
    } else {
        return nil;
    }
}

- (OverviewController *)defaultOverviewController {
    OverviewController *active = [self activeOverviewController];
    if (active) {
        return active;
    }
    
    if ([_overviewControllers count] == 0) {
        [self newOverviewController:nil];
        return [_overviewControllers firstObject];
    } else {
        return [_overviewControllers firstObject];
    }
}

- (IBAction)showOverviewController:(id)sender {
    if ([self activeOverviewController]) {
        return;
    }
    
    if ([_overviewControllers count] == 0) {
        [self newOverviewController:sender];
    } else {
        [[_overviewControllers firstObject] showWindow:sender];
    }
}

- (IBAction)newOverviewController:(id)sender {
    OverviewController *controller = [OverviewController new];
    [_overviewControllers addObject:controller];
    [controller showWindow:nil];
    NSMutableArray *controllers = _overviewControllers;
    __weak id weakController = controller;
    __block __weak id observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification object:[controller window] queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        [controllers removeObject:weakController];
        [[NSNotificationCenter defaultCenter] removeObserver:observer];
    }];
}

- (IBAction)newDocument:(id)sender {
    
}

- (IBAction)searchAllProblems:(id)sender {
    [self showOverviewController:nil];
    [[self activeOverviewController] searchAllProblems:nil];
}

- (void)databaseIncompatible:(NSNotification *)note {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Client out of date", nil);
    alert.informativeText = NSLocalizedString(@"The version of Ship last used to access your database is newer than the version you are currently running. Please download and run the latest version of the app.", nil);
    [alert runModal];
    
    exit(0);
}

- (IBAction)showMarkdownFormattingGuide:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://guides.github.com/features/mastering-markdown/"]];
}

- (IBAction)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.realartists.com/docs/2.0/index.html"]];
}

- (void)protocolIncompatible:(NSNotification *)note {
    [[Reachability sharedInstance] setForceOffline:YES];
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Client out of date", nil);
    alert.informativeText = NSLocalizedString(@"This version of Ship is too old to access the server. Click OK to check for a newer version.", nil);
    [alert runModal];

    SUUpdater *updater = [SUUpdater sharedUpdater];
    [updater checkForUpdates:self];
}

- (void)serverTooOld:(NSNotification *)note {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Server out of date", nil);
    alert.informativeText = NSLocalizedString(@"This version of Ship is too new to access the server. Please update the server to continue using this account.", nil);
    [alert runModal];
}

- (IBAction)showBilling:(id)sender {
    if (!_subscriptionController) {
        _subscriptionController = [SubscriptionController new];
    }
    [_subscriptionController showWindow:sender];

    [[Analytics sharedInstance] track:@"Subscriptions Shown"];
}

- (IBAction)showAcknowledgements:(id)sender {
    if (!_acknowledgementsController) {
        NSWindow *window = [[NSWindow alloc] initWithContentRect:CGRectMake(0, 0, 600, 500) styleMask:NSTitledWindowMask|NSClosableWindowMask|NSResizableWindowMask backing:NSBackingStoreBuffered defer:YES];
        window.title = NSLocalizedString(@"Acknowledgements", nil);
        window.minSize = CGSizeMake(300, 300);
        _acknowledgementsController = [[NSWindowController alloc] initWithWindow:window];
        TextViewController *textController = [[TextViewController alloc] init];
        NSURL *URL = [[NSBundle mainBundle] URLForResource:@"Acknowledgements" withExtension:@"rtf"];
        NSDictionary *opts = @{ NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType, NSCharacterEncodingDocumentAttribute : @(NSUTF8StringEncoding) };
        NSAttributedString *str = [[NSAttributedString alloc] initWithURL:URL options:opts documentAttributes:NULL error:NULL];
        [textController setAttributedStringValue:str];
        _acknowledgementsController.contentViewController = textController;
    }
    
    if (!_acknowledgementsController.window.visible) {
        [_acknowledgementsController.contentViewController scrollToBeginningOfDocument:nil];
        [_acknowledgementsController.window setContentSize:CGSizeMake(600, 500)];
        [_acknowledgementsController.window center];
        [_acknowledgementsController showWindow:sender];
        [_acknowledgementsController.window setContentSize:CGSizeMake(600, 501)];
    } else {
        [_acknowledgementsController showWindow:sender];
    }
}

- (void)showWelcomeIfNeeded {
    Auth *auth = _auth;
    if (auth.authState == AuthStateValid) {
        BOOL shown = [[NSUserDefaults standardUserDefaults] boolForKey:@"WelcomeShown"];
        if (!shown) {
            DebugLog(@"Showing welcome");
            if (!_welcomeController) {
                _welcomeController = [WelcomeHelpController new];
            }
            [_welcomeController loadThenShow:self];
        }
    }
}

- (void)rateLimitChanged:(NSNotification *)note {
    NSDate *prev = note.userInfo[DataStoreRateLimitPreviousEndDateKey];
    NSDate *next = note.userInfo[DataStoreRateLimitUpdatedEndDateKey];
    
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    NSTimeInterval diff = now - _lastRateLimitAlertShown;
    NSTimeInterval longTime = 60 * 60 * 24 * 30;
    
    if (!prev && next && (diff >= longTime)) {
        [[Analytics sharedInstance] track:@"Rate Alert Shown"];
        _lastRateLimitAlertShown = now;
        NSAlert *alert = [NSAlert new];
        alert.alertStyle = NSAlertStyleWarning;
        alert.messageText = NSLocalizedString(@"GitHub Rate Limit Reached", nil);
        alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Unfortunately, due to GitHub limitations, not all of your data can be loaded at this time. Ship will resume syncing by %@.", nil), [next shortUserInterfaceString]];
        [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
        [alert runModal];
    }
}

@end

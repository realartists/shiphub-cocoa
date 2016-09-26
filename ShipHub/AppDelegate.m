//
//  AppDelegate.m
//  ShipHub
//
//  Created by James Howard on 2/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "AppDelegate.h"

#import "Auth.h"
#import "AuthController.h"
#import "DataStore.h"
#import "IssueIdentifier.h"
#import "IssueDocumentController.h"
#import "OverviewController.h"
#import "Reachability.h"
#import "UserNotificationManager.h"
#import "SubscriptionController.h"

#import <HockeySDK/HockeySDK.h>
#import <Sparkle/Sparkle.h>

@interface AppDelegate () <AuthControllerDelegate, BITHockeyManagerDelegate> {
    BOOL _authConfigured;
    BOOL _notificationsRegistered;
    Auth *_nextAuth;
    BOOL _didFinishLaunching;
    NSMutableArray *_pendingURLs;
}

@property (weak) IBOutlet NSWindow *window;

@property Auth *auth;
@property AuthController *authController;
@property SubscriptionController *subscriptionController;

@property IBOutlet NSMenu *accountMenu;
@property IBOutlet NSMenuItem *accountMenuSeparator;

@property (strong) IBOutlet NSMutableArray *overviewControllers;

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
    return _auth.account.login;
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

- (void)handleURL:(NSURL *)URL atAppLaunch:(BOOL)atAppLaunch
{
    if (!URL) return;
    
    if ([[URL scheme] isEqualToString:@"ship+github"]) {
        if ([[URL host] isEqualToString:@"issue"]) {
            NSString *path = [URL path];
            NSString *num = [URL fragment];
            NSString *identifier = [[path substringFromIndex:1] stringByAppendingFormat:@"#%@", num];
            [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:identifier waitForIt:atAppLaunch];
        } else if ([[URL host] isEqualToString:@"signup"]) {
            [_authController continueWithLaunchURL:URL];
        }
    } else if ([[URL scheme] isEqualToString:@"https"]) {
        if ([[URL host] isEqualToString:@"github.com"]) {
            NSNumber *commentIdentifier = nil;
            NSString *issueIdentifier = [NSString issueIdentifierWithGitHubURL:URL commentIdentifier:&commentIdentifier];
            if (issueIdentifier) {
                [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:issueIdentifier canOpenExternally:YES scrollToCommentWithIdentifier:commentIdentifier completion:nil];
            }
        }
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
    while ([_accountMenu itemAtIndex:0] != _accountMenuSeparator) {
        [_accountMenu removeItemAtIndex:0];
    }
    
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
        item.representedObject = nil;
        added++;
    }
    
    if ([_auth.account.login length] && _auth.authState == AuthStateValid) {
        _accountMenu.title = _auth.account.login;
    } else {
        _accountMenu.title = NSLocalizedString(@"Account", nil);
    }
    
    _accountMenuSeparator.hidden = added == 0;
}

- (void)documentController:(NSDocumentController *)documentController
didCloseAllForAccountChange:(BOOL)didCloseAll
               contextInfo:(void *)contextInfo {
    if (_nextAuth) {
        [self authController:nil authenticated:_nextAuth];
        _nextAuth = nil;
    } else {
        _auth = nil;
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
    
    dispatch_block_t changeBlock = ^{
        if (login) {
            _nextAuth = [Auth authWithAccountPair:login];
        } else {
            [_auth logout];
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
        } else {
            alert.messageText = NSLocalizedString(@"Are you sure you want to logout?", nil);
            alert.informativeText = NSLocalizedString(@"Logging out will deauthorize your access on this computer only.", nil);
            [alert addButtonWithTitle:NSLocalizedString(@"Logout", nil)];
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
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://beta.realartists.com/docs/2.0/index.html"]];
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

- (IBAction)showBilling:(id)sender {
    if (!_subscriptionController) {
        _subscriptionController = [SubscriptionController new];
    }
    [_subscriptionController showWindow:sender];
}

@end

//
//  AppDelegate.m
//  Reviewed By Me
//
//  Created by James Howard on 8/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEAppDelegate.h"

#import "Auth.h"
#import "RMEAuthController.h"
#import "RMEDocumentController.h"
#import "RMEDataStore.h"
#import "TextViewController.h"

typedef NS_ENUM(NSInteger, AccountMenuAction) {
    AccountMenuActionLogout = 1,
    AccountMenuActionNewAccount = 2
};

@interface RMEAppDelegate () <RMEAuthControllerDelegate> {
    BOOL _authConfigured;
    BOOL _notificationsRegistered;
    Auth *_nextAuth;
    BOOL _didFinishLaunching;
    NSMutableArray *_pendingURLs;
}

@property (weak) IBOutlet NSWindow *window;

@property Auth *auth;
@property RMEAuthController *authController;

@property (strong) NSWindowController *acknowledgementsController;

@property IBOutlet NSMenu *accountMenu;

@end

@implementation RMEAppDelegate

+ (instancetype)sharedDelegate {
    return (RMEAppDelegate *)[NSApp delegate];
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

- (void)configureDataStoreAndShowUI {
    if (_auth && [[RMEDataStore activeStore] auth] != _auth) {
        RMEDataStore *store = [RMEDataStore storeWithAuth:_auth];
        [store activate];
    }
}

- (void)registerForNotifications {
    if (_notificationsRegistered)
        return;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authChanged:) name:AuthStateChangedNotification object:nil];
    
    _notificationsRegistered = YES;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    [[NSAppleEventManager sharedAppleEventManager]
     setEventHandler:self
     andSelector:@selector(handleURLEvent:withReplyEvent:)
     forEventClass:kInternetEventClass
     andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _authController = [RMEAuthController new];
    _authController.delegate = self;
    [self configureAuth];
    [self registerForNotifications];
    [self rebuildAccountMenu];
    [self showAuthIfNeededAnimated:NO];
    [self configureDataStoreAndShowUI];
    
    _didFinishLaunching = YES;
    for (NSURL *URL in _pendingURLs) {
        [self handleURL:URL atAppLaunch:YES];
    }
    [_pendingURLs removeAllObjects];
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)app {
    [self showOpenWindow];
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
    
#if 0
    if ([[URL scheme] isEqualToString:@"https"]) {
        NSNumber *commentIdentifier = nil;
        NSNumber *reviewCommentIdentifier = nil;
        NSString *issueIdentifier = [NSString issueIdentifierWithGitHubURL:URL commentIdentifier:&commentIdentifier];
        NSString *diffIdentifier = [PullRequest issueIdentifierForGitHubFilesURL:URL commentIdentifier:&reviewCommentIdentifier];
        if (issueIdentifier) {
            [[PRDocumentController sharedDocumentController] openIssueWithIdentifier:issueIdentifier canOpenExternally:YES scrollToCommentWithIdentifier:commentIdentifier completion:nil];
            return YES;
        } else if (diffIdentifier) {
            [[PRDocumentController sharedDocumentController] openDiffWithIdentifier:diffIdentifier canOpenExternally:YES scrollInfo:nil completion:nil];
            return YES;
        }
    }
#endif
    
    return NO;
}

- (void)openURL:(NSURL *)URL {
    BOOL handled = [self handleURL:URL atAppLaunch:NO];
    if (!handled) {
        [[NSWorkspace sharedWorkspace] openURL:URL];
    }
}

- (void)showOpenWindow {
    [[RMEDocumentController sharedDocumentController] openDocument:self];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(logout:))
    {
        return _auth != nil && _auth.authState == AuthStateValid;
    }
    return YES;
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
            // FIXME: Close all open documents
        }
    }
}

- (void)authController:(RMEAuthController *)controller authenticated:(Auth *)auth newAccount:(BOOL)isNewAccount {
    Trace();
    
    [controller close];
    self.auth = auth;
    
    [self rebuildAccountMenu];
    [self configureDataStoreAndShowUI];
    [self showOpenWindow];
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
        [self authController:nil authenticated:_nextAuth newAccount:NO];
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
    
    BOOL logout = login == nil && [sender tag] == AccountMenuActionLogout;
    BOOL addNew = login == nil && [sender tag] == AccountMenuActionNewAccount;
    
    dispatch_block_t changeBlock = ^{
        if (login) {
            _nextAuth = [Auth authWithAccountPair:login];
        } else if (logout) {
            [_auth logout];
            _nextAuth = nil;
        } else if (addNew) {
            _nextAuth = nil;
        }
        
        [_authController close];
        
        RMEDocumentController *docController = [RMEDocumentController sharedDocumentController];
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
            alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Change account to %@?", nil), loginName];
            alert.informativeText = NSLocalizedString(@"Changing accounts will close all open pull requests.", nil);
            [alert addButtonWithTitle:NSLocalizedString(@"Change Account", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        } else if (logout) {
            alert.messageText = NSLocalizedString(@"Are you sure you want to logout?", nil);
            alert.informativeText = NSLocalizedString(@"Logging out close all open pull requests and will delete your GitHub OAuth token from your Mac's Keychain.", nil);
            [alert addButtonWithTitle:NSLocalizedString(@"Logout", nil)];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        } else /* addNew */ {
            alert.messageText = NSLocalizedString(@"Are you sure you want to change to a new account?", nil);
            alert.informativeText = NSLocalizedString(@"Changing accounts will close all open pull requests.", nil);
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

- (IBAction)showMarkdownFormattingGuide:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://guides.github.com/features/mastering-markdown/"]];
}

- (IBAction)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.realartists.com/docs/ReviewedByMe/index.html"]];
}

- (IBAction)emailSupport:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:support@realartists.com"]];
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

- (IBAction)showTwitter:(id)sender {
    NSURL *URL = [NSURL URLWithString:@"https://twitter.com/ShipRealArtists"];
    [[NSWorkspace sharedWorkspace] openURL:URL];
}

@end

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
#import "OverviewController.h"

@interface AppDelegate () <AuthControllerDelegate> {
    BOOL _authConfigured;
    BOOL _notificationsRegistered;
}

@property (weak) IBOutlet NSWindow *window;

@property Auth *auth;
@property AuthController *authController;

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
    
    NSString *lastUsedAccount = [Auth lastUsedLogin];
    NSArray *allAccounts = [Auth allLogins];
    if (![allAccounts containsObject:lastUsedAccount]) {
        lastUsedAccount = nil;
    }
    if (lastUsedAccount) {
        _auth = [Auth authWithLogin:lastUsedAccount];
    }
    if (!_auth) {
        if ([allAccounts count] > 0) {
            _auth = [Auth authWithLogin:[allAccounts firstObject]];
        }
    }
    
    _authConfigured = YES;
}

- (void)registerForDataStoreNotifications {
    if (_notificationsRegistered)
        return;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authChanged:) name:AuthStateChangedNotification object:nil];
    
    _notificationsRegistered = YES;
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _overviewControllers = [NSMutableArray array];
    _authController = [AuthController new];
    _authController.delegate = self;
    [self configureAuth];
    [self registerForDataStoreNotifications];
    [self rebuildAccountMenu];
    [self showAuthIfNeededAnimated:NO];
    [self configureDataStoreAndShowUI];
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


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(logout:)
        || menuItem.action == @selector(showOverviewController:)
        || menuItem.action == @selector(newOverviewController:)
        || menuItem.action == @selector(searchAllProblems:))
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


- (void)showAuthIfNeeded {
    [self showAuthIfNeededAnimated:YES];
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
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to logout?", nil);
    alert.informativeText = NSLocalizedString(@"Logging out will deauthorize your access on this computer only.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Logout", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    if (NSAlertFirstButtonReturn == [alert runModal]) {
        [_auth logout];
        [self authChanged:nil];
    }
}

- (void)rebuildAccountMenu {
    while ([_accountMenu itemAtIndex:0] != _accountMenuSeparator) {
        [_accountMenu removeItemAtIndex:0];
    }
    
    NSInteger added = 0;
    
    for (NSString *login in [[Auth allLogins] reverseObjectEnumerator]) {
        BOOL isMe = [_auth.account.login isEqual:login];
        NSString *title = login;
        if (isMe) {
            title = [NSString stringWithFormat:NSLocalizedString(@"Logged in as %@", nil), login];
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

- (void)changeAccount:(id)sender {
    NSString *login = [sender representedObject];
    if ((login && [_auth.account.login isEqual:login])) {
        return;
    }
    
    if (!login && !_auth.account.login) {
        [self showAuthIfNeededAnimated:YES];
        return;
    }
    
    dispatch_block_t changeBlock = ^{
        // FIXME: Bring this back
#if !INCOMPLETE
        if (accountEmail) {
            _nextAuth = [Auth authWithAccountEmail:accountEmail];
        } else {
            _nextAuth = [Auth authForPendingLogin];
        }
        
        [_overviewControllers makeObjectsPerformSelector:@selector(close)];
        [_adminController close];
        
        ProblemDocumentController *docController = [ProblemDocumentController sharedDocumentController];
        [docController closeAllDocumentsWithDelegate:self didCloseAllSelector:@selector(documentController:didCloseAllForAccountChange:contextInfo:) contextInfo:NULL];
#else
        if (login) {
            [self authController:nil authenticated:[Auth authWithLogin:login]];
        } else {
            _auth = nil;
            [self showAuthIfNeededAnimated:YES];
        }
#endif
    };
    
    if (_auth.authState == AuthStateValid) {
        NSAlert *alert = [[NSAlert alloc] init];
        if (login) {
            alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Logout and change account to %@?", nil), login];
        } else {
            alert.messageText = NSLocalizedString(@"Logout and sign in to another account?", nil);
        }
        alert.informativeText = NSLocalizedString(@"Changing accounts will close all open issues.", nil);
        [alert addButtonWithTitle:NSLocalizedString(@"Change Account", nil)];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
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

@end

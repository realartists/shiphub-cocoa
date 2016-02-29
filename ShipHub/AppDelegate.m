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

@interface AppDelegate () {
    BOOL _authConfigured;
    BOOL _notificationsRegistered;
}

@property (weak) IBOutlet NSWindow *window;

@property Auth *auth;
@property AuthController *authController;

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
    if (!_auth) {
        _auth = [Auth authForPendingLogin];
    }
    
    _authConfigured = YES;
}

- (void)registerForDataStoreNotifications {
    if (_notificationsRegistered)
        return;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authChanged:) name:AuthStateChangedNotification object:nil];
    
    _notificationsRegistered = YES;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    _authController = [AuthController new];
    [self configureAuth];
    [self registerForDataStoreNotifications];
    _authController.auth = _auth;
    [self showAuthIfNeededAnimated:NO];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)showAuthIfNeeded {
    [self showAuthIfNeededAnimated:YES];
}

- (void)showAuthIfNeededAnimated:(BOOL)animated {
    if (_auth.authState != AuthStateValid) {
        [_authController showIfNeeded:nil];
        
    }
}

- (void)authChanged:(NSNotification *)note {
    [self showAuthIfNeededAnimated:YES];
}

- (void)authFinished:(Auth *)auth {
    Trace();
    
    [_authController close];
}

@end

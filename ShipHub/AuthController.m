//
//  AuthController.m
//  Ship
//
//  Created by James Howard on 6/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "AuthController.h"

#import "Auth.h"
#import "Extras.h"
#import "WelcomeViewController.h"
#import "NavigationController.h"
#import "SignInController.h"

@interface AuthWindow : NSWindow

@end

@interface AuthController () <NSWindowDelegate> {
    BOOL _registered;
}

@property IBOutlet NSView *container;

@property NavigationController *navVC;
@property WelcomeViewController *welcomeVC;

@end

@implementation AuthController

- (NSString *)windowNibName {
    return @"AuthController";
}

- (void)windowDidLoad {
    NSWindow *window = self.window;
    window.movableByWindowBackground = YES;
    
    window.delegate = self;
    window.opaque = NO;
    window.backgroundColor = [NSColor clearColor];
    
    NSView *contentView = window.contentView;
    contentView.layer.opaque = NO;
    contentView.layer.contents = [NSImage imageNamed:@"hero"];
    contentView.layer.contentsGravity = kCAGravityResizeAspectFill;
    [contentView.layer setMasksToBounds:YES];
    [contentView.layer setCornerRadius:8.0];
    
    _welcomeVC = [[WelcomeViewController alloc] init];
    _welcomeVC.authController = self;
    _navVC = [[NavigationController alloc] initWithRootViewController:_welcomeVC];
    
    [_container setContentView:_navVC.view];
    
    [[self window] display];
    [[self window] setHasShadow:NO];
    [[self window] setHasShadow:YES];
}

- (void)showWelcomeAnimated:(BOOL)animate {
    [_navVC popToRootViewControllerAnimated:animate];
}

- (SignInController *)showSignInAnimated:(BOOL)animate {
    if (!self.window.isVisible) {
        [self showWindow:nil];
    }
    
    if (![_navVC.topViewController isKindOfClass:[SignInController class]]) {
        if ([_navVC.viewControllers count] > 1) {
            [_navVC popToRootViewControllerAnimated:NO];
        }
        SignInController *vc = [SignInController new];
        vc.authController = self;
        [_navVC pushViewController:vc animated:animate];
        return vc;
    } else {
        return (SignInController *)_navVC.topViewController;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)presentError:(NSError *)error {
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse returnCode) { }];
    return YES;
}

- (IBAction)showWindow:(id)sender {
    [self window];
    if (self.auth.account != nil) {
        [self showSignInAnimated:NO];
    } else {
        [self showWelcomeAnimated:NO];
    }
    [super showWindow:sender];
}

- (IBAction)showIfNeeded:(id)sender {
    if (_auth.authState != AuthStateValid) {
        [self showWindow:sender];
    }
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect {
    rect.origin.y -= 5.0;
    return rect;
}

@end

@implementation AuthWindow

- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }

@end


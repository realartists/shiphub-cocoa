//
//  AuthController.m
//  Ship
//
//  Created by James Howard on 6/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "AuthController.h"

#import "NavigationController.h"
#import "WelcomeController.h"

#import "Auth.h"
#import "Extras.h"

@interface AuthWindow : NSWindow

@end

@interface AuthController () <NSWindowDelegate>

@property IBOutlet NSView *container;

@property IBOutlet NavigationController *nav;

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
    
    [[self window] display];
    [[self window] setHasShadow:NO];
    [[self window] setHasShadow:YES];
}

+ (AuthController *)authControllerForViewController:(NSViewController *)vc {
    return (AuthController *)vc.view.window.delegate;
}

- (IBAction)showWindow:(id)sender {
    [self window];
    [self start];
    
    [super showWindow:sender];
}

- (void)start {
    WelcomeController *welcome = [WelcomeController new];
    _nav = [[NavigationController alloc] initWithRootViewController:welcome];
    
    [_container setContentView:_nav.view];
}

- (void)continueWithViewController:(NSViewController *)vc {
    if (!_nav) {
        [self start];
    }
    
    [_nav pushViewController:vc animated:NO];
    [super showWindow:nil];
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect {
    rect.origin.y -= 5.0;
    return rect;
}

@end

@implementation AuthWindow {
    NSTextView *_whiteFieldEditor;
}

- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }

- (nullable NSText *)fieldEditor:(BOOL)createFlag forObject:(nullable id)anObject {
    NSTextView *view = (NSTextView *)[super fieldEditor:createFlag forObject:anObject];
    if (view && [anObject respondsToSelector:@selector(drawsBackground)] && [anObject drawsBackground]) {
        view.insertionPointColor = [NSColor blackColor];
    } else {
        view.insertionPointColor = [NSColor whiteColor];
    }
    return view;
}

@end


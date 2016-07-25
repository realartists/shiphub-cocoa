//
//  AuthController.m
//  Ship
//
//  Created by James Howard on 6/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "AuthController.h"

#import "NavigationController.h"
#import "BasicAuthController.h"

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

- (IBAction)showWindow:(id)sender {
    [self window];
    [self start];
    
    [super showWindow:sender];
}

- (void)start {
    BasicAuthController *basic = [BasicAuthController new];
    _nav = [[NavigationController alloc] initWithRootViewController:basic];
    
    [_container setContentView:_nav.view];
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


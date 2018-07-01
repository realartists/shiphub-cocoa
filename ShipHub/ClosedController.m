//
//  ClosedController.m
//  Ship
//
//  Created by James Howard on 7/1/18.
//  Copyright © 2018 Real Artists, Inc. All rights reserved.
//

#import "ClosedController.h"

@interface ClosedController () {
    NSModalSession _session;
}

@property IBOutlet NSButton *closeButton;

@end

@implementation ClosedController

- (NSNibName)windowNibName {
    return @"ClosedController";
}

- (void)windowDidLoad {
    [super windowDidLoad];
}

- (void)showWindow:(id)sender {
    NSWindow *window = self.window;
    [[window standardWindowButton:NSWindowDocumentIconButton] setImage:[NSImage imageNamed:@"AppIcon"]];
    [window center];
    [window makeFirstResponder:_closeButton];
    [window makeKeyAndOrderFront:sender];
    [NSApp runModalForWindow:window];
    [NSApp terminate:nil];
}

- (IBAction)closeAction:(id)sender {
    [NSApp stopModal];
}

@end

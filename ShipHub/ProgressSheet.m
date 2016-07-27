//
//  ProblemProgressController.m
//  Ship
//
//  Created by James Howard on 5/21/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "ProgressSheet.h"

@interface ProgressSheet ()

@property IBOutlet NSProgressIndicator *progress;
@property IBOutlet NSTextField *label;

@end

@implementation ProgressSheet

- (NSString *)windowNibName { return @"ProgressSheet"; }

- (void)updateMessage {
    _label.stringValue = self.message ?: NSLocalizedString(@"Operation in progress ...", nil);
}

- (void)windowDidLoad {
    [super windowDidLoad];
    [self updateMessage];
}

- (void)setMessage:(NSString *)message {
    _message = [message copy];
    [self updateMessage];
}

- (void)beginSheetInWindow:(NSWindow *)window {
    if (self.window.sheetParent) return;
    
    [window beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        [_progress stopAnimation:nil];
    }];
    [_progress startAnimation:nil];
}

- (void)endSheet {
    [self.window.sheetParent endSheet:self.window];
}

@end

//
//  SaveSearchController.m
//  Ship
//
//  Created by James Howard on 7/29/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SaveSearchController.h"

@interface SaveSearchController ()

@property IBOutlet NSButton *saveButton;
@property IBOutlet NSTextField *titleField;

@end

@implementation SaveSearchController

- (NSString *)windowNibName {
    return @"SaveSearchController";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    _titleField.stringValue = @"";
    _saveButton.enabled = NO;
}

- (void)setTitle:(NSString *)title {
    [self window];
    [_titleField setStringValue:title ?: @""];
    NSNotification *note = [[NSNotification alloc] initWithName:NSControlTextDidChangeNotification object:self userInfo:nil];
    [self controlTextDidChange:note];
}

- (NSString *)title {
    return _titleField.stringValue;
}

- (void)beginSheetModalForWindow:(NSWindow *)window completionHandler:(void (^)(NSInteger result))handler {
    [window beginSheet:self.window completionHandler:handler];
}

- (IBAction)cancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)save:(id)sender {
    if (_titleField.stringValue.length > 0) {
        [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj {
    _saveButton.enabled = [[self title] length] > 0;
}

@end

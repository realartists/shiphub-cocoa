//
//  IssueLockController.m
//  ShipHub
//
//  Created by James Howard on 7/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "IssueLockController.h"

@interface IssueLockController ()

@property IBOutlet NSTextField *titleField;
@property IBOutlet NSTextView *instructionsText;
@property IBOutlet NSTextView *lockText;
@property IBOutlet NSTextView *unlockText;
@property IBOutlet NSButton *lockButton;

@end

@implementation IssueLockController

- (NSString *)nibName { return @"IssueLockController"; }

- (void)setCurrentlyLocked:(BOOL)currentlyLocked {
    [self view];
    
    _currentlyLocked = currentlyLocked;
    NSTextView *source = currentlyLocked ? _unlockText : _lockText;
    [_instructionsText.textStorage setAttributedString:source.textStorage];
    
    _titleField.stringValue = currentlyLocked
    ? NSLocalizedString(@"Unlock Conversation", nil)
    : NSLocalizedString(@"Lock Conversation", nil);
    
    _lockButton.title = currentlyLocked
    ? NSLocalizedString(@"Unlock Issue", nil)
    : NSLocalizedString(@"Lock Issue", nil);
}

- (IBAction)toggleLock:(id)sender {
    IssueLockControllerAction action = self.actionBlock;
    action(!_currentlyLocked);
}

@end

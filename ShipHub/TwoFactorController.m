//
//  TwoFactorController.m
//  ShipHub
//
//  Created by James Howard on 2/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "TwoFactorController.h"

#import "NavigationController.h"

@interface TwoFactorController ()

@property IBOutlet NSTextField *twoFactor;
@property IBOutlet NSButton *actionButton;
@property IBOutlet NSProgressIndicator *progress;

@end

@implementation TwoFactorController

- (id)initWithTwoFactorContinuation:(AuthTwoFactorContinuation)continuation {
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Two Factor Authentication", nil);
        self.continuation = continuation;
        self.navigationItem.skipOnUnwind = YES;
    }
    return self;
}

- (NSString *)nibName {
    return @"TwoFactorController";
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.view.window makeFirstResponder:_twoFactor];
}

- (void)resetUI {
    _twoFactor.stringValue = @"";
    _actionButton.hidden = NO;
    [_progress stopAnimation:nil];
    _progress.hidden = YES;
}

- (void)retryCode {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Invalid Code", nil);
    alert.informativeText = NSLocalizedString(@"GitHub rejected the provided two factor authentication code.", nil);
    [alert addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self resetUI];
            [self.view.window makeFirstResponder:_twoFactor];
        } else {
            // Go back to Sign In
            [self.navigationController popViewControllerAnimated:YES];
        }
    }];
}

- (IBAction)submit:(id)sender {
    
}

@end

//
//  SignInController.m
//  Ship
//
//  Created by James Howard on 1/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "SignInController.h"

#import "Auth.h"
#import "Error.h"
#import "Extras.h"
#import "NavigationController.h"
#import "TwoFactorController.h"
#import "ChooseReposController.h"

@interface AlphaDisabledButton : NSButton

@property (nonatomic, assign) CGFloat disabledAlpha;

@end

@interface SignInController () <NSTextFieldDelegate> {
    BOOL _disappearing;
    BOOL _submitting;
}

@property IBOutlet NSTextField *label;
@property IBOutlet NSTextField *email;
@property IBOutlet NSTextField *password;
@property IBOutlet AlphaDisabledButton *actionButton;
@property IBOutlet AlphaDisabledButton *forgotButton;
@property IBOutlet NSProgressIndicator *progress;

@end

@implementation SignInController

- (id)init {
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Sign in to GitHub", nil);
    }
    return self;
}

- (NSString *)nibName {
    return @"SignInController";
}

- (void)viewDidLoad {
    [super viewDidLoad];
//    [_forgotButton setTextColor:[NSColor whiteColor]];
    _actionButton.disabledAlpha = 0.0;
    _forgotButton.disabledAlpha = 0.5;
}

- (void)resetUI {
    self.navigationItem.hidesBackButton = NO;
    [_progress stopAnimation:nil];
    _actionButton.hidden = NO;
    _progress.hidden = YES;
    _email.enabled = YES;
    _password.enabled = YES;
    _forgotButton.enabled = YES;
    _label.stringValue = @"";
    
    [self validateActionButton];
}

- (void)startAction:(NSString *)action {
    self.navigationItem.hidesBackButton = YES;
    _email.enabled = NO;
    _password.enabled = NO;
    _progress.hidden = NO;
    _actionButton.hidden = YES;
    _forgotButton.enabled = NO;
    [_progress startAnimation:nil];
    _label.stringValue = action;
}

- (void)viewWillAppear:(BOOL)animated {
    [self view]; // force view to load
    
    [self resetUI];
}

- (void)viewDidAppear:(BOOL)animated {
    if (_email.enabled && _password.enabled) {
        if ([_email.stringValue validateEmail]) {
            [self.view.window makeFirstResponder:_password];
        } else {
            [self.view.window makeFirstResponder:_email];
        }
    }
}

- (void)validateActionButton {
    _actionButton.enabled =
        ([_email.stringValue validateEmail] && [_password.stringValue length] > 0)
        || [_password.stringValue isUUID];
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self validateActionButton];
}

- (void)viewWillDisappear:(BOOL)animated {
    _disappearing = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    _disappearing = NO;
}

- (IBAction)submit:(id)sender {
    if (!_actionButton.enabled || _disappearing) {
        return;
    }
    
    [self startAction:NSLocalizedString(@"Signing in ...", nil)];
    
    [self.authController.auth authorizeWithLogin:_email.stringValue password:_password.stringValue twoFactor:^(AuthTwoFactorContinuation cont) {
        
        if ([self.navigationController.topViewController isKindOfClass:[TwoFactorController class]]) {
            TwoFactorController *twoFA = (id)self.navigationController.topViewController;
            twoFA.continuation = cont;
            [twoFA retryCode];
        } else {
            TwoFactorController *twoFA = [[TwoFactorController alloc] initWithTwoFactorContinuation:cont];
            [self.navigationController pushViewController:twoFA animated:YES];
        }
        
    } chooseRepos:^(ServerConnection *conn, AuthAccount *account, NSArray *repos, dispatch_block_t commit) {
        
        if (![self.navigationController.topViewController isKindOfClass:[ChooseReposController class]]) {
            ChooseReposController *reposController = [ChooseReposController new];
            [reposController updateWithRepos:repos];
            [self.navigationController pushViewController:reposController animated:YES];
        }
        
    } completion:^(NSError *error) {
        
        if (error) {
            [self.authController presentError:error];
        } else {
            
        }
        
    }];
}

- (IBAction)forgot:(id)sender {
    if (_disappearing) {
        return;
    }
    
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/password_reset"]];
}

- (void)setEmailString:(NSString *)emailString {
    [self view];
    
    _email.stringValue = emailString ?: @"";
}

- (NSString *)emailString {
    [self view];
    
    return _email.stringValue;
}

@end

@implementation AlphaDisabledButton

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    if (enabled) {
        self.animator.alphaValue = 1.0;
    } else {
        self.animator.alphaValue = self.disabledAlpha;
    }
}

@end

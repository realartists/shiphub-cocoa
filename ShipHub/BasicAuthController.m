//
//  BasicAuthController.m
//  ShipHub
//
//  Created by James Howard on 3/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "BasicAuthController.h"

#import "Auth.h"
#import "AuthController.h"
#import "Error.h"
#import "Extras.h"
#import "NavigationController.h"
#import "ServerConnection.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface AlphaDisabledButton : NSButton

@property (nonatomic, assign) CGFloat disabledAlpha;

@end

@interface WhiteTextField : NSTextField

@end

@interface BasicAuthController () <NSTextFieldDelegate>

@property IBOutlet NSTextField *username;
@property IBOutlet NSTextField *password;
@property IBOutlet NSTextField *oneTimeCode;

@property IBOutlet NSView *box;

@property IBOutlet NSProgressIndicator *progress;
@property IBOutlet NSButton *goButton;

@property IBOutlet NSButton *infoButton;

@end

@implementation BasicAuthController

- (NSString *)nibName {
    return @"BasicAuthController";
}

- (id)init {
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Real Artists Ship", nil);
        
        NSMutableAttributedString *shipString = [NSMutableAttributedString new];
        
        NSFont *font = [NSFont fontWithName:@"Helvetica-Bold" size:24.0];
        NSFont *italic = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
        
        [shipString appendAttributes:@{ NSFontAttributeName : font,
                                        NSForegroundColorAttributeName : [NSColor whiteColor] } format:@"Real Artists "];
        [shipString appendAttributes:@{ NSFontAttributeName : italic,
                                        NSForegroundColorAttributeName : [NSColor ra_orange] } format:@"Ship"];
        
        NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
        para.alignment = NSTextAlignmentCenter;
        [shipString addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, shipString.length)];
        
        self.navigationItem.attributedTitle = shipString;
    }
    return self;
}

- (void)viewDidAppear {
    [self.view.window makeFirstResponder:_username];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _username.delegate = self;
    _password.delegate = self;
    
    _username.placeholderAttributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"GitHub Username", nil) attributes:@{ NSForegroundColorAttributeName : [[NSColor whiteColor] colorWithAlphaComponent:0.8], NSFontAttributeName : _username.font }];
    
    _password.placeholderAttributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Password", nil) attributes:@{ NSForegroundColorAttributeName : [[NSColor whiteColor] colorWithAlphaComponent:0.8], NSFontAttributeName : _password.font }];
    
    _oneTimeCode.placeholderAttributedString = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"1 Time Code", nil) attributes:@{ NSForegroundColorAttributeName : [[NSColor whiteColor] colorWithAlphaComponent:0.8], NSFontAttributeName : _oneTimeCode.font }];
    
    _box.wantsLayer = YES;
    _box.layer.backgroundColor = [[[NSColor blackColor] colorWithAlphaComponent:0.2] CGColor];
    _box.layer.cornerRadius = 8.0;
    
    NSMutableAttributedString *str = [_infoButton.attributedTitle mutableCopy];
    [str addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, str.length)];
    
    _infoButton.attributedTitle = str;
    
    _progress.hidden = YES;
}

- (void)flashField:(NSTextField *)field {
    NSView *flash = [[NSView alloc] initWithFrame:field.frame];
    flash.wantsLayer = YES;
    flash.layer.backgroundColor = [[NSColor whiteColor] CGColor];
    flash.layer.opacity = 0.0;
    
    CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
    a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    a.duration = 0.1;
    a.fromValue = @0.0;
    a.toValue = @0.5;
    a.repeatCount = 1.5;
    a.autoreverses = YES;
    a.removedOnCompletion = YES;
    
    [[field superview] addSubview:flash positioned:NSWindowBelow relativeTo:field];
    
    NSView *toRemove = flash;
    [flash.layer addAnimation:a forKey:@"flash" completion:^(BOOL finished) {
        [toRemove removeFromSuperview];
    }];
}


- (NSString *)clientID {
    //return @"eac522c6b68c504b2aac";
    switch (DefaultsServerEnvironment()) {
        case ServerEnvironmentDevelopment:
        case ServerEnvironmentJW:
        case ServerEnvironmentLocal:
            return @"da1cde7cfd134d837ae6";
        default:
            return @"55456285644976e93634";
    }
}

- (NSString *)clientSecret {
    //return @"cc3439df3a004194d920a6eabf303d7e8243281a";
    switch (DefaultsServerEnvironment()) {
        case ServerEnvironmentDevelopment:
        case ServerEnvironmentJW:
        case ServerEnvironmentLocal:
            return @"3aeb9af555d7d2285120b133304c34e5a8058078";
        default:
            return @"044a8c057d8a00f023f4c19932d0fcbb77deaa57";
    }
}

- (NSString *)ghHost {
    return @"api.github.com";
}

- (NSString *)shipHost {
    return [ServerConnection defaultShipHubHost];
}

- (IBAction)go:(id)sender {
    if ([_username.stringValue length] == 0) {
        [self.view.window makeFirstResponder:_username];
        [self flashField:_username];
        return;
    }
    if ([_password.stringValue length] == 0) {
        [self.view.window makeFirstResponder:_password];
        [self flashField:_password];
        return;
    }
    
    Auth *existing = [Auth authWithLogin:_username.stringValue];
    if (existing) {
        [self finishWithAuth:existing];
        return;
    }
    
    _username.enabled = NO;
    _password.enabled = NO;
    _goButton.hidden = YES;
    _progress.hidden = NO;
    [_progress startAnimation:nil];
    
    // Authenticate with GitHub
    
    // use a unique fingerprint since if we're here, we aren't aware of any tokens and therefore we need a new one.
    NSString *fingerprint = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/authorizations/clients/%@", [self ghHost], [self clientID]]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"PUT";

    NSString *authStr = [NSString stringWithFormat:@"%@:%@", _username.stringValue, _password.stringValue];
    NSData *authData = [authStr dataUsingEncoding:NSUTF8StringEncoding];
    NSString *auth64 = [authData base64EncodedStringWithOptions:0];
    
    [request setValue:[NSString stringWithFormat:@"Basic %@", auth64] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    NSDictionary *bodyDict = @{ @"scopes": [@"user:email,repo,admin:repo_hook,read:org,admin:org_hook" componentsSeparatedByString:@","],
                                @"client_id": [self clientID],
                                @"client_secret": [self clientSecret],
                                @"fingerprint": fingerprint };
    
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:NULL];
    
    DebugLog(@"%@", request);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        DebugLog(@"%@", http);
        if (data) {
            DebugLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }
        
        if (http.statusCode == 200 || http.statusCode == 201) {
            NSError *decodeErr = nil;
            NSDictionary *reply = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeErr];
            if (decodeErr == nil && ![reply isKindOfClass:[NSDictionary class]]) {
                decodeErr = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            NSString *oauthToken = nil;
            if (!decodeErr) {
                oauthToken = reply[@"token"];
            }
            if (!decodeErr && [oauthToken length] == 0) {
                decodeErr = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            if (decodeErr) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentError:decodeErr];
                });
            } else {
                [self sayHello:oauthToken];
            }
        } else if (http.statusCode == 401 && [http allHeaderFields][@"X-GitHub-OTP"] != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self requestOneTimeCode];
            });
        } else if (http.statusCode == 404 || http.statusCode == 401) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:[NSError shipErrorWithCode:ShipErrorCodeInvalidPassword]];
            });
        } else {
            if (!error) {
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:error];
            });
        }
        
    }] resume];
}

- (void)sayHello:(NSString *)oauthToken {
    // callable from any queue, so we're not necessarily on the main queue here.
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/authentication/hello",
                  [self shipHost]]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    NSDictionary *body = @{ @"accessToken" : oauthToken,
                            @"applicationId" : [self clientID],
                            @"clientName" : [[NSBundle mainBundle] bundleIdentifier] };
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    
    DebugLog(@"%@", request);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        DebugLog(@"%@", http);
        if (data) {
            DebugLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }
        
        if (http.statusCode == 200 || http.statusCode == 201) {
            NSError *decodeErr = nil;
            NSDictionary *reply = [NSJSONSerialization JSONObjectWithData:data options:0 error:&decodeErr];
            if (decodeErr == nil && ![reply isKindOfClass:[NSDictionary class]]) {
                decodeErr = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            
            NSString *shipToken = nil;
            NSDictionary *userDict = nil;
            NSDictionary *billingState = nil;
            
            if (!decodeErr) {
                shipToken = reply[@"session"];
                userDict = reply[@"user"];
                billingState = reply[@"billing"];
            }
            
            if (!decodeErr && ([shipToken length] == 0 || !userDict))
            {
                decodeErr = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            
            if (decodeErr) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentError:decodeErr];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finishWithShipToken:shipToken ghToken:oauthToken user:userDict billing:billingState];
                });
            }
        } else {
            if (!error) {
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:error];
            });
        }
    }] resume];
}

- (void)finishWithShipToken:(NSString *)shipToken ghToken:(NSString *)ghToken user:(NSDictionary *)user billing:(NSDictionary *)billing
{
    NSAssert([NSThread isMainThread], nil);
    
    [self resetUI];
    
    // FIXME: Do something with billing
    
    NSMutableDictionary *accountDict = [user mutableCopy];
    [accountDict setObject:@"ghHost" forKey:[self ghHost]];
    [accountDict setObject:@"shipHost" forKey:[self shipHost]];

    AuthAccount *account = [[AuthAccount alloc] initWithDictionary:user];
    Auth *auth = [Auth authWithAccount:account shipToken:shipToken ghToken:ghToken];

    [self finishWithAuth:auth];
}

- (void)finishWithAuth:(Auth *)auth {
    AuthController *ac = (AuthController *)self.view.window.delegate;
    [ac.delegate authController:ac authenticated:auth];
}

- (IBAction)moreInformation:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.realartists.com"]];
}

- (IBAction)submitUsername:(id)sender {
    [self.view.window makeFirstResponder:_password];
}

- (IBAction)submitPassword:(id)sender {
    if ([_username.stringValue length]) {
        [self go:sender];
    } else {
        [self.view.window makeFirstResponder:_username];
    }
}

- (IBAction)submitOneTimeCode:(id)sender {
    if ([_username.stringValue length] == 0) {
        [self.view.window makeFirstResponder:_username];
    } else if ([_password.stringValue length] == 0) {
        [self.view.window makeFirstResponder:_password];
    } else {
        [self go:sender]; // we don't require any one time code to proceed.
    }
}

- (BOOL)presentError:(NSError *)error {
    [_progress stopAnimation:nil];
    _progress.hidden = YES;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [error localizedDescription];
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        [self resetUI];
        [self.view.window makeFirstResponder:_username];
    }];
    return YES;
}

- (void)resetUI {
    _username.enabled = YES;
    _password.enabled = YES;
    _goButton.hidden = NO;
    [_progress stopAnimation:nil];
    _progress.hidden = YES;
}

- (void)requestOneTimeCode {
    [self resetUI];
    [self.view.window makeFirstResponder:_oneTimeCode];
    [self flashField:_oneTimeCode];
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

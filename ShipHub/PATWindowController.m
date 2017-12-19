//
//  PATWindowController.m
//  Ship
//
//  Created by James Howard on 12/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PATWindowController.h"

#import "Auth.h"
#import "Error.h"
#import "Extras.h"
#import "RequestPager.h"

@interface PATWindowController ()

@property (readonly) Auth *auth;

@property IBOutlet NSButton *generateButton;
@property IBOutlet NSButton *cancelButton;
@property IBOutlet NSTextField *username;
@property IBOutlet NSTextField *password;
@property IBOutlet NSTextField *oneTimeCode;
@property IBOutlet NSProgressIndicator *progress;

@property id task; // responds to -cancel

@property (copy) void (^completion)(BOOL didSet);

@end

@implementation PATWindowController

- (id)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        _auth = auth;
    }
    return self;
}

- (NSString *)windowNibName {
    return @"PATWindowController";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _username.stringValue = _auth.account.login ?: @"";
    _username.enabled = NO;
}

- (IBAction)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.realartists.com/docs/2.0/start.html#github-organization-access"]];
}

- (IBAction)cancel:(id)sender {
    [_task cancel];
    _task = nil;
    self.completion(NO);
    [self close];
    CFRelease((__bridge CFTypeRef)self);
}

- (IBAction)generate:(id)sender {
    if (_task) return;
    
    if ([_password.stringValue length] == 0) {
        [self.window makeFirstResponder:_password];
        [self flashField:_password];
        return;
    }
    
    [_password validateEditing];
    [_oneTimeCode validateEditing];
    
    _password.enabled = NO;
    _oneTimeCode.enabled = NO;
    _generateButton.enabled = NO;
    [_progress startAnimation:nil];
    
    // Authenticate with GitHub
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/authorizations", self.auth.account.ghHost]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"POST";
    [self addAuthToRequest:request];
    
    NSString *note = [NSString stringWithFormat:@"Ship (%@)", [[NSProcessInfo processInfo] hostName]];
    NSString *noteURL = @"https://www.realartists.com";
    NSDictionary *bodyDict = @{ @"scopes": @"public_repo",
                                @"note": note,
                                @"note_url" : noteURL };
    
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:NULL];
    
    DebugLog(@"%@", request);
    _task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        _task = nil;
        
        if ([error isCancelError]) {
            return;
        }
        
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
            NSString *token = nil;
            if (!decodeErr) {
                token = reply[@"token"];
            }
            if (!decodeErr && [token length] == 0) {
                decodeErr = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            if (decodeErr) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentError:decodeErr];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finishWithToken:token];
                });
            }
        } else if (http.statusCode == 401 && [http allHeaderFields][@"X-GitHub-OTP"] != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self requestOneTimeCode];
            });
        } else if (http.statusCode == 404 || http.statusCode == 401) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:[NSError shipErrorWithCode:ShipErrorCodeInvalidPassword]];
            });
        } else if (http.statusCode == 422) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self deleteExistingToken:bodyDict];
            });
        } else {
            if (!error) {
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:error];
            });
        }
        
    }];
    [(NSURLSessionDataTask *)_task resume];
}

- (void)flashField:(NSTextField *)field {
    NSView *flash = [[NSView alloc] initWithFrame:field.frame];
    flash.wantsLayer = YES;
    flash.layer.backgroundColor = [[NSColor redColor] CGColor];
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

- (void)addAuthToRequest:(NSMutableURLRequest *)request {
    dispatch_assert_current_queue(dispatch_get_main_queue());
    
    NSString *otp = _oneTimeCode.stringValue;
    
    Auth *basic = [_auth temporaryBasicAuthWithPassword:_password.stringValue otp:otp];
    [basic addAuthHeadersToRequest:request];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
}

- (void)deleteExistingTokenWithID:(NSNumber *)tokenID {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/authorizations/%@", _auth.account.ghHost, tokenID]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"DELETE";
    [self addAuthToRequest:request];
    
    _task =
    [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        _task = nil;
        
        if ([error isCancelError]) {
            return;
        }
        
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        DebugLog(@"%@", http);
        if (data) {
            DebugLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }
        
        if (http.statusCode == 204) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self generate:nil];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:error?:[NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse]];
            });
        }
    }];
    [(NSURLSessionDataTask *)_task resume];
}

- (void)deleteExistingToken:(NSDictionary *)requestBody {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/authorizations", _auth.account.ghHost]];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"GET";
    request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    [self addAuthToRequest:request];
    
    RequestPager *pager = [[RequestPager alloc] initWithAuth:[_auth temporaryBasicAuthWithPassword:_password.stringValue otp:_oneTimeCode.stringValue]];
    
    _task = [NSProgress indeterminateProgress];
    [pager fetchPaged:[pager get:@"authorizations"] completion:^(NSArray *reply, NSError *err) {
        BOOL cancelled = [_task isCancelled];
        
        _task = nil;
        
        if (cancelled) {
            return;
        }
        
        NSDictionary *existing = [[reply filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"note = %@", requestBody[@"note"]]] firstObject];
        if (existing) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self deleteExistingTokenWithID:existing[@"id"]];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:[NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse]];
            });
        }
    }];
}

- (void)resetUI {
    Trace();
    _oneTimeCode.enabled = YES;
    _password.enabled = YES;
    _generateButton.enabled = YES;
    [_progress stopAnimation:nil];
}

- (void)requestOneTimeCode {
    [self resetUI];
    [self.window makeFirstResponder:_oneTimeCode];
    [self flashField:_oneTimeCode];
}

- (BOOL)presentError:(NSError *)error {
    [_progress stopAnimation:nil];
    _progress.hidden = YES;
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [error localizedDescription];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        [self resetUI];
        [self.window makeFirstResponder:_password];
    }];
    return YES;
}

- (void)finishWithToken:(NSString *)token {
    [_auth setPersonalAccessToken:token];
    self.completion(YES);
    [self close];
    CFRelease((__bridge CFTypeRef)self);
}

- (void)runWithCompletion:(void (^)(BOOL didSetPAT))completion {
    NSAssert(_completion == nil, nil);
    CFRetain((__bridge CFTypeRef)self);
    self.completion = completion;
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:_password];
}

@end

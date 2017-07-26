//
//  OAuthController.m
//  ShipHub
//
//  Created by James Howard on 8/15/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "OAuthController.h"

#import "Defaults.h"
#import "Error.h"
#import "Extras.h"
#import "AuthController.h"
#import "NavigationController.h"

@interface OAuthController () {
    BOOL _processed;
}

@property IBOutlet NSProgressIndicator *progress;

@property (copy) NSString *code;

@end

@implementation OAuthController

- (NSString *)nibName {
    return @"OAuthController";
}

- (id)initWithAuthCode:(NSString *)code {
    if (self = [super init]) {
        self.code = code;
        self.shipHost = DefaultShipHost();
        self.title = NSLocalizedString(@"Finishing Signup…", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self resetUI];
}

- (void)viewDidAppear {
    [self processOAuth];
}

- (void)resetUI {
    _progress.hidden = NO;
    [_progress startAnimation:nil];
}

- (void)presentError:(NSError *)error {
    _progress.hidden = YES;
    [_progress stopAnimation:nil];
    
    NSAlert *alert = [NSAlert new];
    alert.messageText = [error localizedDescription];
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (NSURLRequest *)redeemRequest {
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = self.shipHost;
    comps.path = @"/api/authentication/lambda_legacy";
    NSURL *URL = comps.URL;
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:URL];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *body = @{ @"code" : self.code };
    
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    
    return request;
}

- (void)processOAuth {
    if (_processed) {
        return;
    }
    
    _processed = YES;
    
    NSURLRequest *request = [self redeemRequest];
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showRepoSelectionIfNeededForToken:oauthToken];
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

@end

//
//  AppDelegate.m
//  AccountTool
//
//  Created by James Howard on 11/16/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "AppDelegate.h"
#import "Auth.h"
#import "Extras.h"
#import "Error.h"
#import "Logging.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property IBOutlet NSTextField *tokenField;
@property IBOutlet NSTextField *ghHostField;
@property IBOutlet NSTextField *shipHostField;
@property IBOutlet NSProgressIndicator *progress;

@property NSString *shipHost;
@property NSString *ghHost;
@property NSString *login;
@property NSString *identifier;

@end

@implementation AppDelegate

- (IBAction)keychainAccess:(id)sender {
    [[NSWorkspace sharedWorkspace] launchApplication:@"Keychain Access"];
}

- (IBAction)add:(id)sender {
    NSString *token = [[_tokenField stringValue] trim];
    NSString *ghHost = [[_ghHostField stringValue] trim];
    NSString *shipHost = [[_shipHostField stringValue] trim];
    
    _shipHost = shipHost;
    _ghHost = ghHost;
    
    if (token.length == 0 || ghHost.length == 0 || shipHost.length == 0) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"All Fields Are Required";
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
        return;
    }
    
    [self sayHello:token];
}

- (NSString *)clientID {
    return @"da1cde7cfd134d837ae6";
}

- (void)sayHello:(NSString *)oauthToken {
    // callable from any queue, so we're not necessarily on the main queue here.
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/authentication/login",
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
    [_progress startAnimation:nil];
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
            
            NSDictionary *userDict = nil;
            if (!decodeErr) {
                NSMutableDictionary *user = [reply mutableCopy];
                user[@"ghIdentifier"] = user[@"id"];
                user[@"identifier"] = user[@"id"];
                userDict = user;
            }
            
            if (!decodeErr && !userDict)
            {
                decodeErr = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            
            if (decodeErr) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self presentError:decodeErr];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self finishWithShipToken:oauthToken ghToken:oauthToken user:userDict billing:@{}];
                });
            }
        } else {
            if (!error) {
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            ErrLog(@"%@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:error];
            });
        }
    }] resume];
}

- (void)presentError:(NSError *)error {
    [_progress stopAnimation:nil];
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Unable to load token";
    alert.informativeText = [error localizedDescription];
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)finishWithShipToken:(NSString *)shipToken ghToken:(NSString *)ghToken user:(NSDictionary *)user billing:(NSDictionary *)billing
{
    [_progress stopAnimation:nil];
    
    NSMutableDictionary *accountDict = [user mutableCopy];
    accountDict[@"ghHost"] = [self ghHost];
    accountDict[@"shipHost"] = [self shipHost];
    
    AuthAccount *account = [[AuthAccount alloc] initWithDictionary:accountDict];
    Auth *auth = [Auth authWithAccount:account shipToken:shipToken ghToken:ghToken];
    
    NSAlert *alert = [NSAlert new];
    if (auth) {
        alert.messageText = [NSString stringWithFormat:@"Successfully added account %@", account.login];
    } else {
        alert.messageText = [NSString stringWithFormat:@"Unable to add account"];
    }
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

@end

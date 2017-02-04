//
//  HelloController.m
//  ShipHub
//
//  Created by James Howard on 8/15/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "HelloController.h"

#import "Auth.h"
#import "AuthController.h"
#import "Error.h"
#import "Extras.h"
#import "Defaults.h"

@interface HelloController ()

@end

@implementation HelloController

- (id)init {
    if (self = [super init]) {
        self.shipHost = DefaultShipHost();
        self.ghHost = DefaultGHHost();
    }
    return self;
}

- (NSString *)clientID {
    return @"da1cde7cfd134d837ae6";
}

- (void)sayHello:(NSString *)oauthToken {
    // callable from any queue, so we're not necessarily on the main queue here.
    
    if ([_shipHost isEqualToString:_ghHost]) {
        [self sayHelloLocal:oauthToken];
        return;
    }
    
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

- (void)sayHelloLocal:(NSString *)oauthToken {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/user",
                                       [self ghHost]]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    [request setValue:[NSString stringWithFormat:@"token %@", oauthToken] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    request.HTTPMethod = @"GET";
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self presentError:error];
            });
        } else {
            NSMutableDictionary *user = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL];
            user[@"ghIdentifier"] = user[@"id"];
            user[@"identifier"] = [NSString stringWithFormat:@"%@", user[@"id"]];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self finishWithShipToken:@"local" ghToken:oauthToken user:user billing:@{}];
            });
        }
        
    }] resume];
}

- (void)finishWithShipToken:(NSString *)shipToken ghToken:(NSString *)ghToken user:(NSDictionary *)user billing:(NSDictionary *)billing
{
    NSAssert([NSThread isMainThread], nil);
    
    [self resetUI];
    
    NSMutableDictionary *accountDict = [user mutableCopy];
    accountDict[@"ghHost"] = [self ghHost];
    accountDict[@"shipHost"] = [self shipHost];
    accountDict[@"publicReposOnly"] = @([self publicReposOnly]);
    
    AuthAccount *account = [[AuthAccount alloc] initWithDictionary:accountDict];
    Auth *auth = [Auth authWithAccount:account shipToken:shipToken ghToken:ghToken sessionCookies:self.sessionCookies];
    
    [self finishWithAuth:auth];
}

- (void)finishWithAuth:(Auth *)auth {
    AuthController *ac = (AuthController *)self.view.window.delegate;
    [ac.delegate authController:ac authenticated:auth];
}

- (void)resetUI {
    [self doesNotRecognizeSelector:_cmd];
}

- (void)presentError:(NSError *)error {
    [self doesNotRecognizeSelector:_cmd];
}

+ (NSString *)privateRepoScopes {
    return @"user:email,repo,admin:repo_hook,read:org,admin:org_hook";
}

+ (NSString *)publicRepoScopes {
    return @"user:email,public_repo,admin:repo_hook,read:org,admin:org_hook,notifications";
    
}


@end

//
//  ServerConnection.m
//  ShipHub
//
//  Created by James Howard on 2/26/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "ServerConnection.h"

#import "Auth.h"
#import "Error.h"

@interface ServerConnection ()

@property (strong) Auth *auth;

@end

@implementation ServerConnection

+ (NSString *)defaultShipHubHost {
    switch (DefaultsServerEnvironment()) {
        case ServerEnvironmentLocal:
            return @"api.github.com";
        case ServerEnvironmentDevelopment:
            return @"hub-nick.realartists.com";
        case ServerEnvironmentJW:
            return @"hub-jw.realartists.com";
        case ServerEnvironmentStaging:
            return @"hub-staging.realartists.com";
        case ServerEnvironmentProduction:
        default:
            return @"hub.realartists.com";
    }
}

- (id)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        self.auth = auth;
    }
    return self;
}

- (NSMutableURLRequest *)requestWithHost:(NSString *)host endpoint:(NSString *)endpoint authenticated:(BOOL)authenticate {
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = host;
    comps.path = endpoint;
    
    NSURL *URL = [comps URL];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:URL];
    if (authenticate) {
        [_auth addAuthHeadersToRequest:req];
    }
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    return req;
}

- (void)perform:(NSString *)method on:(NSString *)endpoint body:(id)jsonBody completion:(void (^)(id jsonResponse, NSError *error))completion
{
    if (DefaultsServerEnvironment() != ServerEnvironmentLocal) {
        endpoint = [@"/github" stringByAppendingString:endpoint];
    }
    
    NSMutableURLRequest *request = [self requestWithHost:_auth.account.shipHost endpoint:endpoint authenticated:YES];
    request.HTTPMethod = method;
    
    if (jsonBody) {
        NSError *err = nil;
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:jsonBody options:0 error:&err];
        
        if (err) {
            completion(nil, err);
            return;
        }
    }
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *http = (id)response;
        if ([_auth checkResponse:http]) {
            
            if (http.statusCode < 200 || http.statusCode >= 400) {
                if (!error) {
                    error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
                }
            }
            
            if (!error) {
                id responseJSON = nil;
                if (data.length) {
                    NSError *err = nil;
                    responseJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
                    if (err) {
                        error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
                    }
                }
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    completion(responseJSON, error);
                });
            } else {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    completion(nil, error);
                });
            }
            
        } else {
            error = [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken];
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(nil, error);
            });
        }
        
    }] resume];
}

#define DebugResponse(data, response, error) do { DebugLog(@"response:\n%@\ndata:\n%@\nerror:%@", [response debugDescription], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], error); } while (0)

@end

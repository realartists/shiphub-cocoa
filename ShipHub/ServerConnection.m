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

- (id)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        self.auth = auth;
    }
    return self;
}

- (NSMutableURLRequest *)requestWithHost:(NSString *)host endpoint:(NSString *)endpoint authenticated:(BOOL)authenticate headers:(NSDictionary *)headers
{
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
    
    for (NSString *key in [headers allKeys]) {
        [req setValue:headers[key] forHTTPHeaderField:key];
    }
    
    return req;
}

- (void)perform:(NSString *)method on:(NSString *)endpoint body:(id)jsonBody completion:(void (^)(id jsonResponse, NSError *error))completion {
    [self perform:method on:endpoint headers:nil body:jsonBody completion:completion];
}

- (void)perform:(NSString *)method on:(NSString *)endpoint headers:(NSDictionary *)headers body:(id)jsonBody completion:(void (^)(id jsonResponse, NSError *error))completion
{
    [self perform:method on:endpoint forGitHub:YES headers:headers body:jsonBody completion:completion];
}

#define DebugResponse(data, response, error) do { DebugLog(@"response:\n%@\ndata:\n%@\nerror:%@", [response debugDescription], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], error); } while (0)

- (void)perform:(NSString *)method on:(NSString *)endpoint forGitHub:(BOOL)forGitHub headers:(NSDictionary *)headers body:(id)jsonBody completion:(void (^)(id jsonResponse, NSError *error))completion
{
    if (forGitHub && ![_auth.account.shipHost isEqualToString:_auth.account.ghHost]) {
        endpoint = [@"/github" stringByAppendingString:endpoint];
    }
    
    NSMutableURLRequest *request = [self requestWithHost:_auth.account.shipHost endpoint:endpoint authenticated:YES headers:headers];
    request.HTTPMethod = method;
    if (!([method isEqualToString:@"GET"] || [method isEqualToString:@"HEAD"])) {
        request.cachePolicy = NSURLRequestReloadIgnoringCacheData;
    }
    
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
                    NSMutableDictionary *userInfo = [NSMutableDictionary new];
                    userInfo[ShipErrorUserInfoHTTPResponseCodeKey] = @(http.statusCode);
                    
                    id errorJSON = nil;
                    if ([data length]) {
                        errorJSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                        if ([errorJSON isKindOfClass:[NSDictionary class]]) {
                            NSArray *errors = [errorJSON objectForKey:@"errors"];
                            NSString *message = [errorJSON objectForKey:@"message"];
                            NSString *desc = nil;
                            if ([errors isKindOfClass:[NSArray class]] && [errors count] > 0) {
                                NSDictionary *err1 = [errors firstObject];
                                if ([err1 isKindOfClass:[NSDictionary class]]) {
                                    NSString *errmsg = [err1 objectForKey:@"message"];
                                    if ([errmsg isKindOfClass:[NSString class]] && [errmsg length] > 0) {
                                        desc = errmsg;
                                    }
                                }
                            }
                            if (desc == nil && [message isKindOfClass:[NSString class]] && [message length] > 0) {
                                desc = message;
                            }
                            if ([desc length]) {
                                userInfo[NSLocalizedDescriptionKey] = desc;
                            }
                        }
                    }
                    
                    if (errorJSON) {
                        userInfo[ShipErrorUserInfoErrorJSONBodyKey] = errorJSON;
                    }
                    
                    error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse userInfo:userInfo];
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
                
                if (error) {
                    DebugResponse(data, response, error);
                }
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    completion(responseJSON, error);
                });
            } else {
                DebugResponse(data, response, error);
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    completion(nil, error);
                });
            }
            
        } else {
            error = [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken];
            
            DebugResponse(data, response, error);
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                completion(nil, error);
            });
        }
        
    }] resume];
}

@end

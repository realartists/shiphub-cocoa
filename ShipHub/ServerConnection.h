//
//  ServerConnection.h
//  ShipHub
//
//  Created by James Howard on 2/26/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Auth;
@class AuthAccount;

@interface ServerConnection : NSObject

- (id)initWithAuth:(Auth *)auth;

- (void)perform:(NSString *)method on:(NSString *)endpoint body:(id)jsonBody completion:(void (^)(id jsonResponse, NSError *error))completion;
- (void)perform:(NSString *)method on:(NSString *)endpoint headers:(NSDictionary *)headers body:(id)jsonBody completion:(void (^)(id jsonResponse, NSError *error))completion;
- (void)perform:(NSString *)method on:(NSString *)endpoint forGitHub:(BOOL)forGitHub headers:(NSDictionary *)headers body:(id)jsonBody completion:(void (^)(id jsonResponse, NSError *error))completion;
- (void)perform:(NSString *)method on:(NSString *)endpoint forGitHub:(BOOL)forGitHub headers:(NSDictionary *)headers body:(id)jsonBody extendedCompletion:(void (^)(NSHTTPURLResponse *httpResponse, id jsonResponse, NSError *error))completion;

@property (readonly, strong) Auth *auth;

@end

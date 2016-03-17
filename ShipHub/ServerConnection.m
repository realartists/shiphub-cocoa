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
        NSString *header = [host containsString:@"realartists.com"] ? @"Authorisation" : @"Authorization";
        [req setValue:[NSString stringWithFormat:@"token %@", self.auth.token] forHTTPHeaderField:header];
    }
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    return req;
}

#define DebugResponse(data, response, error) do { DebugLog(@"response:\n%@\ndata:\n%@\nerror:%@", [response debugDescription], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], error); } while (0)

@end

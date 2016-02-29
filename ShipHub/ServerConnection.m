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

@property (weak) Auth *auth;
@property (copy) NSString *gitHubHost;
@property (copy) NSString *shipHubHost;

@end

@implementation ServerConnection

- (id)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        self.auth = auth;
        self.gitHubHost = @"api.github.com";
        switch (DefaultsServerEnvironment()) {
            case ServerEnvironmentDevelopment:
                self.shipHubHost = @"devhub.realartists.com";
                break;
            case ServerEnvironmentJW:
                self.shipHubHost = @"jwhub.realartists.com";
                break;
            case ServerEnvironmentProduction:
                self.shipHubHost = @"apihub.realartists.com";
                break;
            case ServerEnvironmentStaging:
                self.shipHubHost = @"apihub-staging.realartists.com";
                break;
            default: break;
        }
    }
    return self;
}

- (id)initWithAuth:(Auth *)auth gitHubEnterpriseHost:(NSString *)gitHubEnterpriseHost shipHubEnterpriseHost:(NSString *)shipHubEnterpriseHost {
    if (self = [super init]) {
        self.auth = auth;
        self.gitHubHost = gitHubEnterpriseHost;
        self.shipHubHost = shipHubEnterpriseHost;
    }
    return self;
}

- (NSMutableURLRequest *)requestWithHost:(NSString *)host endpoint:(NSString *)endpoint authenticated:(BOOL)authenticate {
    NSURL *URL = [[NSURL alloc] initWithScheme:@"https" host:host path:endpoint];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:URL];
    if (authenticate) {
        NSString *header = [host containsString:@"realartists.com"] ? @"Authorisation" : @"Authorization";
        [req setValue:[NSString stringWithFormat:@"token %@", self.auth.token] forHTTPHeaderField:header];
    }
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    return req;
}

#define DebugResponse(data, response, error) do { DebugLog(@"response:\n%@\ndata:\n%@\nerror:%@", [response debugDescription], [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding], error); } while (0)

- (void)loadAccountWithCompletion:(void (^)(AuthAccount *account, NSArray *allRepos, NSArray *chosenRepos, NSError *error))completion {
    NSMutableURLRequest *req = [self requestWithHost:self.shipHubHost endpoint:@"hello" authenticated:YES];
    req.HTTPMethod = @"GET";
    Trace();
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    
        DebugResponse(data, response, error);
        
        if (!error && !data) {
            error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        NSDictionary *result = nil;
        if (!error) {
            NSError *parseError = nil;
            result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            if (parseError) {
                ErrLog(@"Error parsing result: %@", parseError);
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            } else if (result[@"user"] == nil || result[@"allRepos"] == nil || result[@"chosenRepos"] == nil) {
                ErrLog(@"Missing user|allRepos|chosenRepos in response");
                error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
        }
        
        if (!error) {
            AuthAccount *account = [AuthAccount new];
            account.login = result[@"user"][@"login"];
            account.identifier = result[@"user"][@"identifier"];
            account.name = result[@"user"][@"name"];
            account.extra = result[@"user"];
            
            completion(account, result[@"allRepos"], result[@"chosenRepos"], nil);
        } else {
            completion(nil, nil, nil, error);
        }
        
    }] resume];
}

@end

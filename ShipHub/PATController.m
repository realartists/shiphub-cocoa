//
//  PATController.m
//  Ship
//
//  Created by James Howard on 12/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PATController.h"

#import "Auth.h"
#import "Error.h"
#import "PATWindowController.h"

@implementation PATController

- (id)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        _auth = auth;
    }
    return self;
}

static BOOL MatchRequest(NSURLRequest *request, NSString *bind) {
    NSString *path = [request.URL path];
    if ([path hasPrefix:@"/github"]) {
        path = [path substringFromIndex:[@"/github" length]];
    }
    NSArray *pathComps = [path pathComponents];
    
    if ([bind hasPrefix:request.HTTPMethod]) {
        NSString *pathDesc = [bind substringFromIndex:request.HTTPMethod.length + 1];
        NSArray *pathDescComps = [pathDesc pathComponents];
        
        if (pathComps.count == pathDescComps.count) {
            for (NSUInteger i = 0; i < pathComps.count; i++) {
                NSString *actual = pathComps[i];
                NSString *expected = pathDescComps[i];
                
                BOOL isArgument = [expected hasPrefix:@":"];
                
                if (!isArgument && ![expected isEqualToString:actual]) {
                    return NO;
                }
            }
            
            return YES;
        }
    }
    
    return NO;
}

static BOOL IsReplayableWithPAT(NSURLRequest *request, NSHTTPURLResponse *response) {
    return
    /* Comment reactions */
    (response.statusCode == 404 && MatchRequest(request, @"POST /repos/:owner/:repo/issues/comments/:id/reactions")) ||
    (response.statusCode == 403 && MatchRequest(request, @"POST /repos/:owner/:repo/pulls/comments/:id/reactions")) ||
    /* Delete reactions */
    (response.statusCode == 403 && MatchRequest(request, @"DELETE /reactions/:id")) ||
    /* Single Pull Request Comments */
    (response.statusCode == 404 && MatchRequest(request, @"POST /repos/:owner/:repo/pulls/:number/comments")) ||
    (response.statusCode == 404 && MatchRequest(request, @"PATCH /repos/:owner/:repo/pulls/comments/:id")) ||
    (response.statusCode == 404 && MatchRequest(request, @"DELETE /repos/:owner/:repo/pulls/comments/:id")) ||
    /* Pull Request Reviews */
    (response.statusCode == 403 && MatchRequest(request, @"POST /repos/:owner/:repo/pulls/:number/reviews"));
}

- (NSURLRequest *)duplicateRequestWithPAT:(NSURLRequest *)original
{
    NSMutableURLRequest *req = [original mutableCopy];
    [self.auth addPersonalAccessAuthHeadersToRequest:req];
    return req;
}

- (BOOL)handleResponse:(NSHTTPURLResponse *)response forInitialRequest:(NSURLRequest *)request completion:(void (^)(NSURLRequest *, BOOL))completion
{
    if (IsReplayableWithPAT(request, response)) {
        if (_auth.personalAccessToken) {
            completion([self duplicateRequestWithPAT:request], NO);
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                PATWindowController *win = [[PATWindowController alloc] initWithAuth:_auth];
                [win runWithCompletion:^(BOOL didSetPAT) {
                    if (didSetPAT) {
                        completion([self duplicateRequestWithPAT:request], YES);
                    } else {
                        completion(nil, YES);
                    }
                }];
            });
        }
        return YES;
    }
    return NO;
}

@end

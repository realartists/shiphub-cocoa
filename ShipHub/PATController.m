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

@interface PATController ()

@property PATWindowController *activeWindowController;
@property NSMutableArray *completions;

@end

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
                if (!_completions) {
                    _completions = [NSMutableArray new];
                }
                void (^winCompletion)(BOOL) = ^(BOOL didSetPAT) {
                    if (didSetPAT) {
                        completion([self duplicateRequestWithPAT:request], YES);
                    } else {
                        completion(nil, YES);
                    }
                };
                [_completions addObject:[winCompletion copy]];
                if (!_activeWindowController) {
                    _activeWindowController = [[PATWindowController alloc] initWithAuth:_auth];
                    PATController *x = self; // allow retain cycle until window controller finishes its thing.
                    [_activeWindowController runWithCompletion:^(BOOL didSetPAT) {
                        NSArray *completions = x.completions;
                        x.completions = nil;
                        x.activeWindowController = nil;
                        for (void (^c)(BOOL) in completions) {
                            c(didSetPAT);
                        }
                    }];
                } else {
                    [[_activeWindowController window] makeKeyAndOrderFront:nil];
                }
            });
        }
        return YES;
    }
    return NO;
}

@end

//
//  HelloController.h
//  ShipHub
//
//  Created by James Howard on 8/15/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;

@interface HelloController : NSViewController

@property (copy) NSString *ghHost;
@property (copy) NSString *shipHost;

- (NSString *)clientID;

- (void)sayHello:(NSString *)oauthToken;
- (void)finishWithShipToken:(NSString *)shipToken ghToken:(NSString *)ghToken user:(NSDictionary *)user billing:(NSDictionary *)billing;
- (void)finishWithAuth:(Auth *)auth;

// Subclassers to implement:
- (void)resetUI;
- (void)presentError:(NSError *)error;

@end

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

+ (NSString *)defaultShipHubHost;

- (id)initWithAuth:(Auth *)auth;
- (id)initWithAuth:(Auth *)auth gitHubEnterpriseHost:(NSString *)gitHubEnterpriseHost shipHubEnterpriseHost:(NSString *)shipHubEnterpriseHost;

@property (readonly, strong) Auth *auth;

@property (readonly, copy) NSString *gitHubHost;
@property (readonly, copy) NSString *shipHubHost;

@end

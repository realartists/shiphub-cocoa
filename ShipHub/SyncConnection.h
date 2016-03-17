//
//  SyncConnection.h
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Auth;

@protocol SyncConnectionDelegate;

@interface SyncConnection : NSObject

- (id)initWithAuth:(Auth *)auth;

@property (readonly, strong) Auth *auth;

- (void)syncWithVersions:(NSDictionary *)versions;

@property (weak) id<SyncConnectionDelegate> delegate;

@end

@protocol SyncConnectionDelegate

- (void)syncConnectionDidConnect:(SyncConnection *)sync;
- (void)syncConnectionDidDisconnect:(SyncConnection *)sync;

- (void)syncConnection:(SyncConnection *)sync receivedRootIdentifiers:(NSDictionary *)rootIdentifiers version:(int64_t)version;

/* types are:
    users
    repos
    milestones
    labels
    issues
    events
    comments
    relationships
 */
- (void)syncConnection:(SyncConnection *)sync receivedSyncObjects:(NSArray *)objs type:(NSString *)type version:(int64_t)version;

@end

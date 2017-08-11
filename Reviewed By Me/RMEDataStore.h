//
//  RMEDataStore.h
//  ShipHub
//
//  Created by James Howard on 8/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PullRequest.h"

@class Account;
@class Auth;
@class ServerConnection;
@class PRComment;
@class PRReview;
@class Reaction;
@class Issue;
@class Repo;

@interface RMEDataStore : NSObject

+ (instancetype)storeWithAuth:(Auth *)auth;

+ (instancetype)activeStore;
- (void)activate;
- (void)deactivate;

@property (readonly) Auth *auth;
@property (readonly) ServerConnection *serverConnection;

@property (nonatomic, readonly, getter=isActive) BOOL active; // YES if self == [DataStore activeStore].

- (void)loadFullIssue:(id)issueIdentifier completion:(void (^)(Issue *issue, NSError *error))completion;

- (void)storeLastViewedHeadSha:(NSString *)headSha forPullRequestIdentifier:(NSString *)issueIdentifier pullRequestTitle:(NSString *)title completion:(void (^)(NSString *lastSha, NSError *error))completion; // completion called on arbitrary dispatch queue, not main queue like most DataStore methods

@end

extern NSString *const RMEDataStoreCannotOpenDatabaseNotification;

//
//  SyncConnection.h
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Auth;
@class SyncEntry;

@protocol SyncConnectionDelegate;

@interface SyncConnection : NSObject

- (id)initWithAuth:(Auth *)auth;

@property (readonly, strong) Auth *auth;

- (void)syncWithVersions:(NSDictionary *)versions;

@property (weak) id<SyncConnectionDelegate> delegate;

// Fetch the latest details for issueIdentifier
// and deliver them asynchronously over the normal delegate channel
- (void)updateIssue:(id)issueIdentifier;

@end

@protocol SyncConnectionDelegate

- (void)syncConnectionWillConnect:(SyncConnection *)sync;
- (void)syncConnectionDidConnect:(SyncConnection *)sync;
- (void)syncConnectionDidDisconnect:(SyncConnection *)sync;

- (void)syncConnection:(SyncConnection *)sync receivedEntries:(NSArray<SyncEntry *> *)entries versions:(NSDictionary *)versions progress:(double)progress;

- (BOOL)syncConnection:(SyncConnection *)connection didReceivePurgeIdentifier:(NSString *)purgeIdentifier;

- (void)syncConnectionRequiresSoftwareUpdate:(SyncConnection *)sync;

@end

typedef NS_ENUM(NSInteger, SyncEntryAction) {
    SyncEntryActionSet,
    SyncEntryActionDelete
};

@interface SyncEntry : NSObject

@property SyncEntryAction action;
@property NSString *entityName;
@property id data;

+ (instancetype)entryWithDictionary:(NSDictionary *)dict;

@end

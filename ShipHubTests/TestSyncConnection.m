//
//  TestSyncConnection.m
//  Ship
//
//  Created by James Howard on 6/22/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "TestSyncConnection.h"
#import "TestMetadata.h"
#import "Extras.h"

@interface SyncConnection (Internal)

- (void)connect;
- (void)disconnect;
- (void)heartbeat;

@end

@interface TestSyncConnection () {
    BOOL _testConnected;
    BOOL _sentData;
    BOOL _sentLogs;
}

@end

@implementation TestSyncConnection

- (id)initWithAuth:(Auth *)auth {
    if (self = [super initWithAuth:auth]) {
        
    }
    return self;
}

- (void)dealloc {
    
}

- (void)connect {
    if (!_testConnected && !_offline) {
        _testConnected = YES;
        [self.delegate syncConnectionDidConnect:self];
    }
}

- (void)disconnect {
    if (_testConnected) {
        _testConnected = NO;
        [self.delegate syncConnectionDidDisconnect:self];
    }
}

- (void)setOffline:(BOOL)offline {
    _offline = offline;
    if (offline) [self disconnect];
    else [self connect];
}

- (void)heartbeat {
    // nop
}

- (void)syncWithVersions:(NSDictionary *)versions {
    if (!_sentData) {
        NSArray *users = [[TestMetadata users] arrayByMappingObjects:^id(id obj) {
            SyncEntry *e = [SyncEntry new];
            e.action = SyncEntryActionSet;
            e.entityName = @"user";
            e.data = obj;
            return e;
        }];
        
        NSArray *orgs = [[TestMetadata orgs] arrayByMappingObjects:^id(id obj) {
            SyncEntry *e = [SyncEntry new];
            e.action = SyncEntryActionSet;
            e.entityName = @"org";
            e.data = obj;
            return e;
        }];
        
        NSArray *repos = [[TestMetadata repos] arrayByMappingObjects:^id(id obj) {
            SyncEntry *e = [SyncEntry new];
            e.action = SyncEntryActionSet;
            e.entityName = @"repo";
            e.data = obj;
            return e;
        }];
        
        NSArray *milestones = [[TestMetadata users] arrayByMappingObjects:^id(id obj) {
            SyncEntry *e = [SyncEntry new];
            e.action = SyncEntryActionSet;
            e.entityName = @"milestone";
            e.data = obj;
            return e;
        }];
        
        [self.delegate syncConnection:self receivedEntries:users versions:@{} progress:0.0];
        
        [self.delegate syncConnection:self receivedEntries:orgs versions:@{} progress:0.0];
        
        [self.delegate syncConnection:self receivedEntries:repos versions:@{} progress:0.0];
        
        [self.delegate syncConnection:self receivedEntries:milestones versions:@{} progress:0.0];
    }
}

@end

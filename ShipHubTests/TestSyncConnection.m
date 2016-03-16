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
        [self.delegate syncConnection:self receivedRootIdentifiers:[TestMetadata roots] version:1];
        [self.delegate syncConnection:self receivedSyncObjects:[TestMetadata users] type:@"user" version:1];
        [self.delegate syncConnection:self receivedSyncObjects:[TestMetadata orgs] type:@"org" version:1];
        [self.delegate syncConnection:self receivedSyncObjects:[TestMetadata repos] type:@"repo" version:1];
        [self.delegate syncConnection:self receivedSyncObjects:[TestMetadata milestones] type:@"milestone" version:1];
    }
}

@end

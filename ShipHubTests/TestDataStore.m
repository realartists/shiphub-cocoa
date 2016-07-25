//
//  TestDataStore.m
//  Ship
//
//  Created by James Howard on 6/22/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "TestDataStore.h"
#import "Auth.h"

@interface DataStore (Internals)

- (void)openDB;
- (void)openDBForceRecreate:(BOOL)force;

- (SyncConnection *)syncConnection;
- (ServerConnection *)serverConnection;

@end

@interface TestDataStore () {
    BOOL _offline;
}

@end

@implementation TestDataStore

+ (TestDataStore *)testStore {
    AuthAccount *account = [AuthAccount new];
    account.login = @"test-user-1";
    account.name = @"Test User";
    account.ghIdentifier = @(1);
    account.shipIdentifier = @"test-user-1";
    account.ghHost = @"localhost";
    account.shipHost = @"localhost";
    
    Auth *auth = [Auth authWithAccount:account shipToken:@"open_sesame" ghToken:@"abracadata"];

    return [self storeWithAuth:auth];
}

- (NSString *)dbPath {
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"ShipTests.db"];
}

- (void)openDB {
    // Want a fresh DB for every instance
    [super openDBForceRecreate:YES];
}

+ (Class)serverConnectionClass {
    return [TestServerConnection class];
}

+ (Class)syncConnectionClassWithAuth:(Auth *)auth {
    return [TestSyncConnection class];
}

- (BOOL)isOffline {
    return self.testSyncConnection.offline;
}

- (TestSyncConnection *)testSyncConnection {
    return (id)[super syncConnection];
}

- (TestServerConnection *)testServerConnection {
    return (id)[super serverConnection];
}

@end

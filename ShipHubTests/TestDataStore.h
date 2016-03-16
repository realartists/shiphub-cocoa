//
//  TestDataStore.h
//  Ship
//
//  Created by James Howard on 6/22/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "DataStore.h"
#import "TestServerConnection.h"
#import "TestSyncConnection.h"

@interface TestDataStore : DataStore

+ (TestDataStore *)testStore;

@property (nonatomic, readonly) TestServerConnection *testServerConnection;
@property (nonatomic, readonly) TestSyncConnection *testSyncConnection;

@end

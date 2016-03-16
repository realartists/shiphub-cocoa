//
//  TestSyncConnection.h
//  Ship
//
//  Created by James Howard on 6/22/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SyncConnection.h"

@interface TestSyncConnection : SyncConnection

@property (nonatomic, getter=isOffline) BOOL offline;

@end

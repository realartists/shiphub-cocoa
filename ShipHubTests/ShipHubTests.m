//
//  ShipHubTests.m
//  ShipHubTests
//
//  Created by James Howard on 3/11/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "TestDataStore.h"

@interface XCTestExpectation (Utility)

- (void)delay:(NSTimeInterval)delay;

@end

@implementation XCTestExpectation (Utility)

- (void)delay:(NSTimeInterval)delay {
    dispatch_queue_t delayQ = dispatch_queue_create("test_delay", NULL);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, delayQ);;
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, delay * NSEC_PER_SEC, (delay * 0.01) * NSEC_PER_SEC);
    __block dispatch_source_t keepalive = timer;
    dispatch_source_set_event_handler(timer, ^{
        [self fulfill];
        keepalive = nil;
    });
    dispatch_resume(timer);
}

@end

@interface ShipHubTests : XCTestCase

@end

@implementation ShipHubTests

- (void)setUp {
    [super setUp];
    
    TestDataStore *store = [TestDataStore testStore];
    [store activate];
}

- (void)tearDown {
    [super tearDown];
    
    TestDataStore *store = [TestDataStore activeStore];
    [store deactivate];
}

- (void)testPopulateSyncData {
    // TestDataStore will populate its own sync data and save it.
    // We merely need to wait for this to happen.
    
    sleep(1);
}

@end

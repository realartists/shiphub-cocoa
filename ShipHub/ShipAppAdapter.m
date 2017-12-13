//
//  ShipAppAdapter.m
//  Ship
//
//  Created by James Howard on 11/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "ShipAppAdapter.h"

#import "AppDelegate.h"
#import "Auth.h"
#import "DataStore.h"

@implementation ShipAppAdapter

+ (ShipAppAdapter *)sharedAdapter {
    static dispatch_once_t onceToken;
    static ShipAppAdapter *adapter;
    dispatch_once(&onceToken, ^{
        adapter = [ShipAppAdapter new];
    });
    return adapter;
}

- (Auth *)auth {
    return [[AppDelegate sharedDelegate] auth];
}

- (void)openURL:(NSURL *)URL {
    [[AppDelegate sharedDelegate] openURL:URL];
}

@end

id<AppAdapter> SharedAppAdapter() {
    return [ShipAppAdapter sharedAdapter];
}

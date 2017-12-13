//
//  RMEAppAdapter.m
//  Reviewed By Me
//
//  Created by James Howard on 11/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEAppAdapter.h"

#import "Auth.h"
#import "RMEAppDelegate.h"
#import "RMEDataStore.h"

@implementation RMEAppAdapter

+ (RMEAppAdapter *)sharedAdapter {
    static dispatch_once_t onceToken;
    static RMEAppAdapter *adapter;
    dispatch_once(&onceToken, ^{
        adapter = [RMEAppAdapter new];
    });
    return adapter;
}

- (Auth *)auth {
    return [[RMEAppDelegate sharedDelegate] auth];
}

- (void)openURL:(NSURL *)URL {
    [[RMEAppDelegate sharedDelegate] openURL:URL];
}

@end

id<AppAdapter> SharedAppAdapter() {
    return [RMEAppAdapter sharedAdapter];
}

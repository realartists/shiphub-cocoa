//
//  IssueNotification.m
//  ShipHub
//
//  Created by James Howard on 9/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueNotification.h"

#import "LocalNotification.h"

@implementation IssueNotification

- (instancetype)initWithLocalNotification:(LocalNotification *)ln {
    if (!ln) return nil;
    
    if (self = [super init]) {
        _identifier = ln.identifier;
        _reason = ln.reason;
        _commentIdentifier = ln.commentIdentifier;
        _updatedAt = ln.updatedAt;
        _lastReadAt = ln.lastReadAt;
        _unread = [ln.unread boolValue];
    }
    return self;
}

@end

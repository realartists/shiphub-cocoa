//
//  IssueEvent.m
//  ShipHub
//
//  Created by James Howard on 3/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueEvent.h"

#import "LocalEvent.h"
#import "LocalUser.h"
#import "MetadataStoreInternal.h"
#import "User.h"
#import "JSON.h"

@implementation IssueEvent

- (instancetype)initWithLocalEvent:(LocalEvent *)le metadataStore:(MetadataStore *)ms
{
    if (self = [super init]) {
        _commitId = le.commitId;
        _commitURL = le.commitURL;
        _createdAt = le.createdAt;
        _event = le.event;
        _identifier = le.identifier;
        _actor = [ms userWithLocalUser:le.actor];
        _assignee = [ms userWithLocalUser:le.assignee];
        if (le.rawJSON) {
            _extra = [NSJSONSerialization JSONObjectWithData:le.rawJSON options:0 error:NULL];
        }
    }
    return self;
}

- (id)JSONDescription {
    return _extra;
}

- (NSString *)description {
    return [_extra description];
}

@end

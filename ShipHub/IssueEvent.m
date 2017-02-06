//
//  IssueEvent.m
//  ShipHub
//
//  Created by James Howard on 3/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueEvent.h"

#import "LocalEvent.h"
#import "LocalAccount.h"
#import "MetadataStoreInternal.h"
#import "Account.h"
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
        _actor = [ms accountWithLocalAccount:le.actor];
        _assignee = [ms accountWithLocalAccount:le.assignee];
        if (le.rawJSON) {
            _extra = [NSJSONSerialization JSONObjectWithData:le.rawJSON options:0 error:NULL];
        }
    }
    return self;
}

- (id)JSONDescription {
    BOOL needsActorLinkage = [_extra[@"actor"] isKindOfClass:[NSNumber class]];
    BOOL needsAssigneeLinkage = [_extra[@"assignee"] isKindOfClass:[NSNumber class]];
    
    if (needsActorLinkage || needsAssigneeLinkage) {
        NSMutableDictionary *e = [_extra mutableCopy];
        if (needsActorLinkage) {
            e[@"actor"] = _actor;
        }
        if (needsAssigneeLinkage) {
            e[@"assignee"] = _assignee;
        }
        return e;
    } else {
        return _extra;
    }
}

- (NSString *)description {
    return [_extra description];
}

@end

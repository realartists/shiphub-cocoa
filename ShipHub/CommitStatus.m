//
//  CommitStatus.m
//  ShipHub
//
//  Created by James Howard on 4/27/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "CommitStatus.h"

#import "LocalCommitStatus.h"
#import "LocalAccount.h"
#import "LocalRepo.h"

#import "Account.h"
#import "Repo.h"
#import "MetadataStore.h"

@implementation CommitStatus

- (id)initWithLocalCommitStatus:(LocalCommitStatus *)lcs metadataStore:(MetadataStore *)ms
{
    if (self = [super init]) {
        _identifier = lcs.identifier;
        _reference = lcs.reference;
        _state = lcs.state;
        _createdAt = lcs.createdAt;
        _updatedAt = lcs.updatedAt;
        _targetUrl = lcs.targetUrl;
        _statusDescription = lcs.statusDescription;
        _context = lcs.context;
        
        _creator = [ms objectWithManagedObject:lcs.creator];
        _repository = [ms objectWithManagedObject:lcs.repository];
    }
    return self;
}

@end

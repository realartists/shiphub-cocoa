//
//  CommitStatus.h
//  ShipHub
//
//  Created by James Howard on 4/27/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Account;
@class Repo;
@class LocalCommitStatus;
@class MetadataStore;

@interface CommitStatus : NSObject

@property NSNumber *identifier;
@property NSString *reference;
@property NSString *state;
@property NSDate *createdAt;
@property NSDate *updatedAt;
@property NSString *targetUrl;
@property NSString *statusDescription;
@property NSString *context;

@property Account *creator;
@property Repo *repository;

- (id)initWithLocalCommitStatus:(LocalCommitStatus *)lcs metadataStore:(MetadataStore *)ms;

@end

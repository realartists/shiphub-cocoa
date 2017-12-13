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

#if TARGET_SHIP
@class LocalCommitStatus;
@class MetadataStore;
#endif

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

#if TARGET_SHIP
- (id)initWithLocalCommitStatus:(LocalCommitStatus *)lcs metadataStore:(MetadataStore *)ms;
#endif

@end

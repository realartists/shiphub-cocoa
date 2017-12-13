//
//  IssueComment.h
//  ShipHub
//
//  Created by James Howard on 3/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Account;
@class LocalComment;
@class Reaction;

#if TARGET_SHIP
@class MetadataStore;
#endif

@interface IssueComment : NSObject

@property NSString *body;
@property NSDate *createdAt;
@property NSNumber *identifier;
@property NSDate *updatedAt;
@property Account *user;
@property NSArray<Reaction *> *reactions;

#if TARGET_SHIP
- (instancetype)initWithLocalComment:(LocalComment *)lc metadataStore:(MetadataStore *)ms;
#endif

@end

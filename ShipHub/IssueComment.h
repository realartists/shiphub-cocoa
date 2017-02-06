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
@class MetadataStore;
@class Reaction;

@interface IssueComment : NSObject

@property NSString *body;
@property NSDate *createdAt;
@property NSNumber *identifier;
@property NSDate *updatedAt;
@property Account *user;
@property NSArray<Reaction *> *reactions;

- (instancetype)initWithLocalComment:(LocalComment *)lc metadataStore:(MetadataStore *)ms;

@end

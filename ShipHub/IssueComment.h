//
//  IssueComment.h
//  ShipHub
//
//  Created by James Howard on 3/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class User;
@class LocalComment;
@class MetadataStore;

@interface IssueComment : NSObject

@property NSString *body;
@property NSDate *createdAt;
@property NSNumber *identifier;
@property NSDate *updatedAt;
@property User *user;

- (instancetype)initWithLocalComment:(LocalComment *)lc metadataStore:(MetadataStore *)ms;

@end
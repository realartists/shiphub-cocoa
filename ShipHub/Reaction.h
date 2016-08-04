//
//  Reaction.h
//  ShipHub
//
//  Created by James Howard on 8/3/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LocalReaction;
@class MetadataStore;
@class User;

@interface Reaction : NSObject

@property NSNumber *identifier;
@property NSString *content;
@property NSDate *createdAt;
@property User *user;

- (instancetype)initWithLocalReaction:(LocalReaction *)lc metadataStore:(MetadataStore *)ms;

@end

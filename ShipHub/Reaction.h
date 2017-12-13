//
//  Reaction.h
//  ShipHub
//
//  Created by James Howard on 8/3/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MetadataItem.h"

@class Account;

#if TARGET_SHIP
@class LocalReaction;
@class MetadataStore;
#endif

@interface Reaction : MetadataItem

@property NSString *content;
@property NSDate *createdAt;
@property Account *user;

#if TARGET_SHIP
- (instancetype)initWithLocalReaction:(LocalReaction *)lc metadataStore:(MetadataStore *)ms;
#endif

@end

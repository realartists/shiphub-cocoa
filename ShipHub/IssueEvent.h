//
//  IssueEvent.h
//  ShipHub
//
//  Created by James Howard on 3/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Account;

#if TARGET_SHIP
@class LocalEvent;
@class MetadataStore;
#endif

@interface IssueEvent : NSObject

@property NSString *commitId;
@property NSString *commitURL;
@property NSDate *createdAt;
@property NSString *event;
@property NSNumber *identifier;
@property Account *actor;
@property Account *assignee;

@property NSDictionary *extra;

#if TARGET_SHIP
- (instancetype)initWithLocalEvent:(LocalEvent *)le metadataStore:(MetadataStore *)ms;
#endif

@end

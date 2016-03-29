//
//  IssueEvent.h
//  ShipHub
//
//  Created by James Howard on 3/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class LocalEvent;
@class MetadataStore;
@class User;

@interface IssueEvent : NSObject

@property NSString *commitId;
@property NSString *commitURL;
@property NSDate *createdAt;
@property NSString *event;
@property NSNumber *identifier;
@property User *actor;
@property User *assignee;

@property NSDictionary *extra;

- (instancetype)initWithLocalEvent:(LocalEvent *)le metadataStore:(MetadataStore *)ms;

@end

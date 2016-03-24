//
//  Issue.h
//  ShipHub
//
//  Created by James Howard on 3/23/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Repo;
@class User;
@class Milestone;
@class Label;

@class LocalIssue;
@class MetadataStore;

@interface Issue : NSObject

@property (readonly) NSString *fullIdentifier; // e.g. realartists/shiphub-server#11
@property (readonly) NSNumber *number;
@property (readonly) NSString *body;
@property (readonly) NSString *title;
@property (readonly) BOOL closed;
@property (readonly) NSDate *createdAt;
@property (readonly) NSDate *updatedAt;
@property (readonly) BOOL locked;
@property (readonly) User *assignee;
@property (readonly) User *closedBy;
@property (readonly) NSArray<Label*> *labels;
@property (readonly) Milestone *milestone;
@property (readonly) Repo *repository;

- (instancetype)initWithLocalIssue:(LocalIssue *)li metadataStore:(MetadataStore *)ms;

@end



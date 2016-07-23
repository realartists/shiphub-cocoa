//
//  CustomQuery.h
//  Ship
//
//  Created by James Howard on 7/28/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JSONItem.h"

@class LocalQuery;

@interface CustomQuery : NSObject <JSONItem>

- (id)initWithLocalItem:(LocalQuery *)query;

@property NSString *identifier;
@property NSString *title;
@property NSNumber *authorIdentifier;
@property NSPredicate *predicate;
@property NSString *predicateString;
@property (readonly) BOOL isMine;

- (NSURL *)URL;
- (NSString *)URLAndTitle;

@property (readonly) NSString *titleWithAuthor;

@end

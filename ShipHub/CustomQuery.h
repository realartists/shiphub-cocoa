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
@class Account;
@class MetadataStore;

@interface CustomQuery : NSObject <JSONItem>

- (id)initWithLocalItem:(LocalQuery *)query metadata:(MetadataStore *)ms;

@property NSString *identifier;
@property NSString *title;
@property NSNumber *authorIdentifier;
@property Account *author;
@property NSPredicate *predicate;
@property NSString *predicateString;
@property (readonly) BOOL isMine;

- (NSURL *)URL;

+ (BOOL)isQueryURL:(NSURL *)URL;
+ (NSString *)identifierFromQueryURL:(NSURL *)URL;

@property (readonly) NSString *titleWithAuthor;

- (CustomQuery *)copyIfNeededForEditing;

@end

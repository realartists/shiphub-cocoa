//
//  TestMetadata.h
//  Ship
//
//  Created by James Howard on 6/22/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TestMetadata : NSObject

+ (NSDictionary *)roots;
+ (NSArray *)users;
+ (NSArray *)orgs;
+ (NSArray *)repos;
+ (NSArray *)milestones;

@end

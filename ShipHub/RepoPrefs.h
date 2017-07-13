//
//  RepoPrefs.h
//  ShipHub
//
//  Created by James Howard on 7/11/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JSONItem.h"

@interface RepoPrefs : NSObject <JSONItem>

@property NSArray<NSNumber *> *whitelist;
@property NSArray<NSNumber *> *blacklist;
@property BOOL autotrack;

@end

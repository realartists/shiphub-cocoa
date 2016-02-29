//
//  JSONItem.h
//  Ship
//
//  Created by James Howard on 5/11/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol JSONItem <NSObject>

- (id)initWithDictionary:(NSDictionary *)d;
- (NSMutableDictionary *)dictionaryRepresentation;

@end

//
//  MetadataItem.h
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MetadataItem : NSObject

#if TARGET_SHIP
- (instancetype)initWithLocalItem:(id)localItem;
#endif
- (instancetype)initWithDictionary:(NSDictionary *)d;

@property NSNumber *identifier;

@end

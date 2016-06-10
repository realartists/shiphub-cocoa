//
//  MultiDownloadProgress.h
//  ShipHub
//
//  Created by James Howard on 6/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MultiDownloadProgress : NSProgress

- (void)addChild:(NSProgress *)progress;
- (void)removeChild:(NSProgress *)progress;

@property (readonly) NSArray *childProgressArray;

@end

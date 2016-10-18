//
//  GitRepo.h
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GitRepo : NSObject

+ (GitRepo *)repoAtPath:(NSString *)path error:(NSError *__autoreleasing *)error;

- (void)readLock;
- (void)writeLock;
- (void)unlock;

// synchronously fetch remote. Acquires writeLock for the duration.
- (NSError *)fetchRemote:(NSURL *)remoteURL refs:(NSArray *)refs;

@end

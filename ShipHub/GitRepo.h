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
- (NSError *)fetchRemote:(NSURL *)remoteURL username:(NSString *)username password:(NSString *)password refs:(NSArray *)refs progress:(NSProgress *)progress;

// synchronously create a branch with proposed name and revert commit
// and then push it to the remote.

- (NSError *)pushRemote:(NSURL *)remoteURL username:(NSString *)username password:(NSString *)password newBranchWithProposedName:(NSString *)branchName revertingCommit:(NSString *)mergeCommit fromBranch:(NSString *)sourceBranch progress:(NSProgress *)progress;

@end

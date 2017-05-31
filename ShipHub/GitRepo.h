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

// synchronously merges srcBranch into dstBranch and pushes it to the remote
// fetch and updateRef should already be run before using this
- (NSError *)mergeBranch:(NSString *)srcBranch intoBranch:(NSString *)dstBranch pushToRemote:(NSURL *)remoteURL username:(NSString *)username password:(NSString *)password progress:(NSProgress *)progress;

// synchronously check if ref is in repo
- (BOOL)hasRef:(NSString *)refName error:(NSError *__autoreleasing *)error;

// create or update refName to point to sha. sha must exist as an object in the repo.
- (NSError *)updateRef:(NSString *)refName toSha:(NSString *)sha;

@end

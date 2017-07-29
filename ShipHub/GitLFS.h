//
//  GitLFS.h
//  ShipHub
//
//  Created by James Howard on 7/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <git2.h>

@class GitRepo;

@interface GitLFSObject : NSObject

+ (instancetype)objectWithOid:(NSString *)oid size:(NSNumber *)size;

@property NSString *oid;
@property NSNumber *size;

@end

typedef void (^GitLFSCompletion)(NSArray<NSData *> *objs, NSError *error);

@interface GitLFS : NSObject

@property NSURL *remoteBaseURL;
@property NSString *remoteUsername;
@property NSString *remotePassword;

@property (readonly, weak) GitRepo *repo;

- (instancetype)initWithRepo:(GitRepo *)repo;

- (void)fetchObjects:(NSArray<GitLFSObject *> *)objects withProgress:(NSProgress *)progress completion:(GitLFSCompletion)completion completionQueue:(dispatch_queue_t)completionQueue;

- (BOOL)isLFSAtPath:(NSString *)path text:(NSString *)text treeSha:(NSString *)treeSha outObject:(GitLFSObject *__autoreleasing *)outObject;

@end

//
//  GitRepo.m
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GitRepoInternal.h"

#import "NSError+Git.h"

@interface GitRepo ()

@property git_repository *repo;

@end

@implementation GitRepo

static void initGit2() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        git_libgit2_init();
    });
}

+ (GitRepo *)repoAtPath:(NSString *)path error:(NSError *__autoreleasing *)error {
    initGit2();
    
    if (error) *error = nil;
    
    git_repository *repo = NULL;
    int err = git_repository_init(&repo, [path fileSystemRepresentation], false /* not bare */);
    if (err) {
        if (error) *error = [NSError gitError];
        return nil;
    }
    
    GitRepo *result = [GitRepo new];
    result.repo = repo;
    return result;
}

- (void)dealloc {
    if (_repo) {
        git_repository_free(_repo);
    }
}

@end

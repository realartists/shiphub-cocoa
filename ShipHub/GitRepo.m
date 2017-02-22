//
//  GitRepo.m
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GitRepoInternal.h"

#import "NSError+Git.h"

#import <pthread.h>

@interface GitRepo () {
    pthread_rwlock_t _rwlock;
}

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
    int err = git_repository_init(&repo, [path fileSystemRepresentation], true /* bare */);
    if (err) {
        if (error) *error = [NSError gitError];
        return nil;
    }
    
    GitRepo *result = [GitRepo new];
    result.repo = repo;
    return result;
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_rwlock_init(&_rwlock, NULL);
    }
    return self;
}

- (void)readLock {
    pthread_rwlock_rdlock(&_rwlock);
}

- (void)writeLock {
    pthread_rwlock_wrlock(&_rwlock);
}

- (void)unlock {
    pthread_rwlock_unlock(&_rwlock);
}

- (void)dealloc {
    if (_repo) {
        git_repository_free(_repo);
    }
    pthread_rwlock_destroy(&_rwlock);
}

- (NSError *)fetchRemote:(NSURL *)remoteURL refs:(NSArray *)refs {
    [self writeLock];
    
    __block git_remote *remote = NULL;
    __block git_strarray refspecs = {0};
    
    dispatch_block_t cleanup = ^{
        if (remote) git_remote_free(remote);
        if (refspecs.strings) {
            for (size_t i = 0; i < refspecs.count; i++) {
                free(refspecs.strings[i]);
            }
            free(refspecs.strings);
        }
        [self unlock];
    };
    
#define CHK(X) \
    do { \
        int giterr = (X); \
        if (giterr) { \
            NSError *err = [NSError gitError]; \
            cleanup(); \
            return err; \
        } \
    } while (0);
    
    
    if ([refs count]) {
        refspecs.strings = malloc(sizeof(char *) * [refs count]);
        refspecs.count = [refs count];
        for (size_t i = 0; i < refspecs.count; i++) {
            refspecs.strings[i] = strdup([refs[i] UTF8String]);
        }
    }
    
    CHK(git_remote_create_anonymous(&remote, _repo, [[remoteURL description] UTF8String]));
    CHK(git_remote_fetch(remote, &refspecs, NULL /*opts*/, NULL /*reflogs msg*/));
    
    cleanup();
    return nil;
}

@end

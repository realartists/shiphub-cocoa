//
//  Commit.m
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GitCommit.h"

#import "Extras.h"
#import "GitRepoInternal.h"
#import "NSError+Git.h"
#import "GitDiffInternal.h"

#import <git2.h>

@interface GitCommit ()

- (id)initWithRepo:(GitRepo *)repo commit:(git_commit *)commit;

@property (readonly) GitDiff *diff;
@property (readonly) GitRepo *repo;
@property (readonly) git_oid *commitOid;

@end

@implementation GitCommit

+ (NSArray<GitCommit *> *)commitLogFrom:(NSString *)baseRev to:(NSString *)headRev inRepo:(GitRepo *)repo error:(NSError *__autoreleasing *)error
{
    NSMutableArray *commits = [NSMutableArray new];
    
    NSParameterAssert(repo);
    NSParameterAssert(baseRev);
    NSParameterAssert(headRev);
    
    [repo readLock];
    
    if (error) *error = nil;
    
    __block git_object *baseObj = NULL;
    __block git_object *headObj = NULL;
    __block git_oid walkOid;
    __block git_commit *walkCommit = NULL;
    __block git_revwalk *walk = NULL;
    
    dispatch_block_t cleanup = ^{
        if (baseObj) git_object_free(baseObj);
        if (headObj) git_object_free(headObj);
        if (walkCommit) git_commit_free(walkCommit);
        if (walk) git_revwalk_free(walk);
        
        [repo unlock];
    };
    
#define CHK(X) \
    do { \
        int giterr = (X); \
        if (giterr) { \
            if (error) *error = [NSError gitError]; \
            cleanup(); \
            return nil; \
        } \
    } while (0);

    CHK(git_revparse_single(&baseObj, repo.repo, [baseRev UTF8String]));
    CHK(git_revparse_single(&headObj, repo.repo, [headRev UTF8String]));
    
    CHK(git_revwalk_new(&walk, repo.repo));
    git_revwalk_sorting(walk, GIT_SORT_TOPOLOGICAL | GIT_SORT_REVERSE);
    
    // start by walking from head
    CHK(git_revwalk_push(walk, git_object_id(headObj)));
    
    // walk back to base
    CHK(git_revwalk_hide(walk, git_object_id(baseObj)));
    
    while ((git_revwalk_next(&walkOid, walk)) == 0) {
        CHK(git_commit_lookup(&walkCommit, repo.repo, &walkOid));
        
        GitCommit *commit = [[GitCommit alloc] initWithRepo:repo commit:walkCommit];
        
        [commits addObject:commit];
    }
    
    cleanup();

#undef CHK
    
    return commits;
}

- (id)initWithRepo:(GitRepo *)repo commit:(git_commit *)commit {
    if (self = [super init]) {
        _repo = repo;
        const git_oid *commitOid = git_commit_id(commit);
        
        _commitOid = malloc(sizeof(git_oid));
        git_oid_cpy(_commitOid, commitOid);
        
        char commitRevBuf[GIT_OID_HEXSZ+1];
        git_oid_tostr(commitRevBuf, sizeof(commitRevBuf), commitOid);
        
        NSString *commitRev = [NSString stringWithUTF8String:commitRevBuf];
        _rev = commitRev;
        
        const git_signature *author = git_commit_author(commit);
        _authorName = [NSString stringWithUTF8String:author->name ?: ""];
        _authorEmail = [NSString stringWithUTF8String:author->email ?: ""];
        git_time_t time = git_commit_time(commit);
        _date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)time];
        
        const char *message = git_commit_message(commit) ?: "";
        _message = [NSString stringWithUTF8String:message];
    }
    return self;
}

- (void)dealloc {
    if (_commitOid) {
        free(_commitOid);
        _commitOid = NULL;
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:
            @"commit %@ (%@ %p)\n"
            @"Author: %@ <%@>\n"
            @"Date:   %@\n\n"
            @"%@\n\n", self.rev, NSStringFromClass([self class]), self, self.authorName, self.authorEmail, self.date, self.message];
}

- (GitDiff *)_loadDiffWithError:(NSError *__autoreleasing *)outError {
    if (outError)
        *outError = nil;
    
    if (_diff)
        return _diff;
    
    __block git_commit *commit = NULL;
    __block git_commit *parentCommit = NULL;
    __block git_tree *commitTree = NULL;
    __block git_tree *parentTree = NULL;
    
    [_repo readLock];
    
    dispatch_block_t cleanup = ^{
        if (commit) git_commit_free(commit);
        if (parentCommit) git_commit_free(parentCommit);
        if (parentTree) git_tree_free(parentTree);
        if (commitTree) git_tree_free(commitTree);
        
        [_repo unlock];
    };
    
    #define CHK(X) \
    do { \
        int giterr = (X); \
        if (giterr) { \
            NSError *error = [NSError gitError]; \
            if (outError) *outError = error; \
            cleanup(); \
            return nil; \
        } \
    } while (0);
    
    const git_oid *commitOid = _commitOid;
    
    CHK(git_commit_lookup(&commit, _repo.repo, commitOid));
    
    CHK(git_commit_parent(&parentCommit, commit, 0));
    
    const git_oid *parentOid = git_commit_id(parentCommit);
    
    char commitRevBuf[GIT_OID_HEXSZ+1];
    char parentRevBuf[GIT_OID_HEXSZ+1];
    
    git_oid_tostr(commitRevBuf, sizeof(commitRevBuf), commitOid);
    git_oid_tostr(parentRevBuf, sizeof(parentRevBuf), parentOid);
    
    NSString *commitRev = [NSString stringWithUTF8String:commitRevBuf];
    NSString *parentRev = [NSString stringWithUTF8String:parentRevBuf];
    
    CHK(git_commit_tree(&commitTree, commit));
    CHK(git_commit_tree(&parentTree, parentCommit));
    
    NSError *diffError = nil;
    _diff = [GitDiff diffWithRepo:_repo fromTree:parentTree fromRev:parentRev toTree:commitTree toRev:commitRev error:&diffError];
    
    cleanup();
    
    #undef CHK
    
    if (*outError) *outError = diffError;
    return _diff;
}

- (void)loadDiff:(void (^)(GitDiff *, NSError *err))completion
{
    if (_diff) {
        RunOnMain(^{
            completion(_diff, nil);
        });
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        _diff = [self _loadDiffWithError:&error];
        
        RunOnMain(^{
            completion(_diff, error);
        });
    });
}

+ (GitDiff *)spanFromCommitRangeStart:(GitCommit *)start end:(GitCommit *)end error:(NSError *__autoreleasing *)outError {
    NSAssert(![NSThread isMainThread], @"shouldn't call this from the main thread");
    NSParameterAssert(start);
    NSParameterAssert(end);
    
    if (outError)
        *outError = nil;
    
    if (start == end) {
        return [start _loadDiffWithError:outError];
    }
    
    __block git_commit *startCommit = NULL;
    __block git_commit *endCommit = NULL;
    __block git_commit *parentCommit = NULL;
    __block git_tree *startTree = NULL;
    __block git_tree *endTree = NULL;
    
    GitRepo *repo = start.repo;
    
    [repo readLock];
    
    dispatch_block_t cleanup = ^{
        if (startCommit) git_commit_free(startCommit);
        if (endCommit) git_commit_free(endCommit);
        if (parentCommit) git_commit_free(parentCommit);
        if (startTree) git_tree_free(startTree);
        if (endTree) git_tree_free(endTree);
        
        [repo unlock];
    };
    
    #define CHK(X) \
    do { \
        int giterr = (X); \
        if (giterr) { \
            NSError *error = [NSError gitError]; \
            if (outError) *outError = error; \
            cleanup(); \
            return nil; \
        } \
    } while (0);

    CHK(git_commit_lookup(&startCommit, start.repo.repo, start.commitOid));
    CHK(git_commit_lookup(&endCommit, end.repo.repo, end.commitOid));
    
    const git_oid *headOid = end.commitOid;
    
    CHK(git_commit_parent(&parentCommit, startCommit, 0));
    
    const git_oid *parentOid = git_commit_id(parentCommit);
    
    char headRevBuf[GIT_OID_HEXSZ+1];
    char parentRevBuf[GIT_OID_HEXSZ+1];
    
    git_oid_tostr(headRevBuf, sizeof(headRevBuf), headOid);
    git_oid_tostr(parentRevBuf, sizeof(parentRevBuf), parentOid);
    
    NSString *headRev = [NSString stringWithUTF8String:headRevBuf];
    NSString *parentRev = [NSString stringWithUTF8String:parentRevBuf];
    
    CHK(git_commit_tree(&endTree, endCommit));
    CHK(git_commit_tree(&startTree, parentCommit));
    
    NSError *diffError = nil;
    GitDiff *diff = [GitDiff diffWithRepo:repo fromTree:startTree fromRev:parentRev toTree:endTree toRev:headRev error:&diffError];
    
    cleanup();
    
#undef CHK
    
    if (*outError) *outError = diffError;
    return diff;

}

@end

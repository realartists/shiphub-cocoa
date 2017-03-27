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

- (id)initWithDiff:(GitDiff *)diff commit:(git_commit *)commit;

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
    
    git_object *baseObj = NULL;
    git_object *headObj = NULL;
    git_oid walkOid;
    git_commit *walkCommit = NULL;
    git_commit *parentCommit = NULL;
    git_tree *walkTree = NULL;
    git_tree *parentTree = NULL;
    git_revwalk *walk = NULL;
    
    dispatch_block_t cleanup = ^{
        if (baseObj) git_object_free(baseObj);
        if (headObj) git_object_free(headObj);
        if (walkCommit) git_commit_free(walkCommit);
        if (parentCommit) git_commit_free(parentCommit);
        if (walkTree) git_tree_free(walkTree);
        if (parentTree) git_tree_free(parentTree);
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
        
        const git_oid *commitOid = git_commit_id(walkCommit);
        
        CHK(git_commit_parent(&parentCommit, walkCommit, 0));
        
        const git_oid *parentOid = git_commit_id(parentCommit);
        
        char commitRevBuf[GIT_OID_HEXSZ+1];
        char parentRevBuf[GIT_OID_HEXSZ+1];
        
        git_oid_tostr(commitRevBuf, sizeof(commitRevBuf), commitOid);
        git_oid_tostr(parentRevBuf, sizeof(parentRevBuf), parentOid);
        
        NSString *commitRev = [NSString stringWithUTF8String:commitRevBuf];
        NSString *parentRev = [NSString stringWithUTF8String:parentRevBuf];
        
        CHK(git_commit_tree(&walkTree, walkCommit));
        CHK(git_commit_tree(&parentTree, parentCommit));
        
        NSError *diffError = nil;
        GitDiff *commitDiff = [GitDiff diffWithRepo:repo fromTree:parentTree fromRev:parentRev toTree:walkTree toRev:commitRev error:&diffError];
        
        if (diffError) {
            cleanup();
            if (error) {
                *error = diffError;
                return nil;
            }
        }
        
        GitCommit *commit = [[GitCommit alloc] initWithDiff:commitDiff commit:walkCommit];
        
        [commits addObject:commit];
        
        git_tree_free(walkTree);
        walkTree = NULL;
        
        git_tree_free(parentTree);
        parentTree = NULL;
        
        git_commit_free(walkCommit);
        walkCommit = NULL;
    }
    
    cleanup();
    
    return commits;
}

- (id)initWithDiff:(GitDiff *)diff commit:(git_commit *)commit {
    if (self = [super init]) {
        _diff = diff;
        _rev = diff.headRev;
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

- (NSString *)description {
    return [NSString stringWithFormat:
            @"commit %@ (%@ %p)\n"
            @"Author: %@ <%@>\n"
            @"Date:   %@\n\n"
            @"%@\n\n", self.rev, NSStringFromClass([self class]), self, self.authorName, self.authorEmail, self.date, self.message];
}

@end

//
//  Diff.m
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GitDiff.h"

#import "Extras.h"
#import "NSError+Git.h"
#import "NSString+Git.h"
#import "GitRepoInternal.h"
#import <git2.h>

@interface GitDiffFile ()

+ (GitDiffFile *)fileWithDelta:(const git_diff_delta *)delta inRepo:(GitRepo *)repo;

@property git_oid newOid;
@property git_oid oldOid;

@property NSString *path;
@property NSString *name;
@property NSString *oldPath;

@property DiffFileOperation operation;
@property DiffFileMode mode;

@property (readwrite, weak) GitFileTree *parentTree;

@property GitRepo *repo;
@property (getter=isBinary) BOOL binary;

@end

@interface GitDiff ()

@property NSArray<GitDiffFile *> *allFiles;
@property GitFileTree *fileTree;

@property NSString *baseRev;
@property NSString *headRev;

@end

@interface GitFileTree ()

@property NSString *dirname;
@property NSString *path;
@property NSMutableArray *mutableChildren;

@property (readwrite, weak) GitFileTree *parentTree;

@end

@implementation GitDiff

static int fileVisitor(const git_diff_delta *delta, float progress, void *ctx)
{
    NSDictionary *info = (__bridge NSDictionary *)ctx;
    [info[@"files"] addObject:[GitDiffFile fileWithDelta:delta inRepo:info[@"repo"]]];
    return 0;
}

+ (GitDiff *)diffWithRepo:(GitRepo *)repo from:(NSString *)baseRev to:(NSString *)headRev error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(repo);
    NSParameterAssert(baseRev);
    NSParameterAssert(headRev);
    
    [repo readLock];
    
    if (error) *error = nil;
    
    git_object *baseObj = NULL;
    git_object *headObj = NULL;
    git_commit *baseCommit = NULL;
    git_commit *headCommit = NULL;
    git_tree *baseTree = NULL;
    git_tree *headTree = NULL;
    git_diff *diff = NULL;
    
    dispatch_block_t cleanup = ^{
        if (baseObj) git_object_free(baseObj);
        if (headObj) git_object_free(headObj);
        if (baseCommit) git_commit_free(baseCommit);
        if (headCommit) git_commit_free(headCommit);
        if (baseTree) git_tree_free(baseTree);
        if (headTree) git_tree_free(headTree);
        if (diff) git_diff_free(diff);
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
    
    CHK(git_commit_lookup(&baseCommit, repo.repo, git_object_id(baseObj)));
    CHK(git_commit_lookup(&headCommit, repo.repo, git_object_id(headObj)));
    
    CHK(git_commit_tree(&baseTree, baseCommit));
    CHK(git_commit_tree(&headTree, headCommit));
    
    CHK(git_diff_tree_to_tree(&diff, repo.repo, baseTree, headTree, NULL));
    
    git_diff_find_options opts = GIT_DIFF_FIND_OPTIONS_INIT;
    opts.flags = GIT_DIFF_FIND_RENAMES | GIT_DIFF_FIND_COPIES;
    CHK(git_diff_find_similar(diff, &opts));
    
    NSMutableArray *files = [NSMutableArray new];
    NSDictionary *info = @{@"files":files, @"repo":repo};
    CHK(git_diff_foreach(diff, fileVisitor, NULL /*binary cb*/, NULL /*hunk cb*/, NULL /*line cb*/, (__bridge void *)info));
    
    GitDiff *result = [[GitDiff alloc] initWithFiles:files baseRev:baseRev headRev:headRev];
    
    cleanup();
    
    return result;
    
#undef CHK
}

- (id)initWithFiles:(NSArray *)files baseRev:(NSString *)baseRev headRev:(NSString *)headRev {
    if (self = [super init]) {
        self.baseRev = baseRev;
        self.headRev = headRev;
        self.allFiles = files;
        [self buildFileTree];
    }
    return self;
}

static NSUInteger pathDepth(NSString *path) {
    NSUInteger c = 0;
    NSRange range = NSMakeRange(0, path.length);
    NSRange found;
    NSUInteger len = range.length;
    while ((found = [path rangeOfString:@"/" options:0 range:range]).location != NSNotFound) {
        c++;
        range.location = found.location + found.length;
        range.length = len - range.location;
    }
    return c;
}

- (void)buildFileTree {
    /*
     This method builds a compressed file tree, suitable for presentation to the user.
     
     For example, consider the following hypothetical file list:
     
     src/com/realartists/shiphub/git/diff.java
     src/com/realartists/shiphub/git/file.java
     src/com/realartists/shiphub/git/commit.java
     src/com/realartists/shiphub/ui/git/viewcontroller.java
     
     This method builds this into a hierarchy like so:
     + src/com/realartists/shiphub
        + git
            diff.java
            file.java
            commit.java
        + ui/git
            viewcontroller.java
    */
     
    NSArray *depthSorted = [_allFiles sortedArrayUsingComparator:^NSComparisonResult(GitDiffFile *a, GitDiffFile *b) {
        NSUInteger aDepth = pathDepth(a.path);
        NSUInteger bDepth = pathDepth(b.path);
        
        if (aDepth < bDepth) {
            return NSOrderedAscending;
        } else if (aDepth > bDepth) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    GitFileTree *root = [GitFileTree new];
    NSMutableDictionary *parents = [NSMutableDictionary new];
    parents[@""] = root;
    
    for (GitDiffFile *file in depthSorted) {
        NSString *dirname = [file.path stringByDeletingLastPathComponent];
        GitFileTree *parent = parents[dirname];
        if (!parent) {
            parent = [GitFileTree new];
            parent.path = dirname;
            
            GitFileTree *grandparent = nil;
            NSString *gpdirname = dirname;
            do {
                gpdirname = [gpdirname stringByDeletingLastPathComponent];
                grandparent = parents[gpdirname];
            } while (grandparent == nil);
            
            NSUInteger subIdx = gpdirname.length;
            if ([dirname characterAtIndex:subIdx] == '/') subIdx++;
            parent.dirname = [dirname substringFromIndex:subIdx];
            
            [grandparent.mutableChildren addObject:parent];
            parent.parentTree = grandparent;
            parents[dirname] = parent;
        }
        
        [parent.mutableChildren addObject:file];
        file.parentTree = parent;
    }
    
    NSMutableArray *q = [NSMutableArray arrayWithObject:root];
    while ([q count]) {
        GitFileTree *tree = [q firstObject];
        [q removeObjectAtIndex:0];
        [tree.mutableChildren sortUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            return [[obj1 name] localizedStandardCompare:[obj2 name]];
        }];
        for (id child in tree.children) {
            if ([child isKindOfClass:[GitFileTree class]]) {
                [q addObject:child];
            }
        }
    }
    
    self.fileTree = root;
}

@end

@implementation GitFileTree

- (id)init {
    if (self = [super init]) {
        self.dirname = @"";
        self.path = @"";
        self.mutableChildren = [NSMutableArray new];
    }
    return self;
}

- (NSArray *)children {
    return _mutableChildren;
}

- (NSString *)name {
    return _dirname;
}

@end

@implementation GitDiffFile

+ (GitDiffFile *)fileWithDelta:(const git_diff_delta *)delta inRepo:(GitRepo *)repo {
    GitDiffFile *f = [GitDiffFile new];
    f.repo = repo;
    if (delta->new_file.path) {
        f.path = [NSString stringWithUTF8String:delta->new_file.path];
    } else if (delta->old_file.path) {
        f.path = [NSString stringWithUTF8String:delta->old_file.path];
    }
    if (delta->old_file.path) {
        f.oldPath = [NSString stringWithUTF8String:delta->old_file.path];
    }
    
    f.binary = (delta->flags & GIT_DIFF_FLAG_BINARY) != 0;
    f.newOid = delta->new_file.id;
    f.oldOid = delta->old_file.id;
    f.mode = (DiffFileMode)delta->new_file.mode;
    if (f.mode == DiffFileModeUnreadable) { /* deleted in new */
        f.mode = (DiffFileMode)delta->old_file.mode;
    }
    f.operation = (DiffFileOperation)delta->status;
    f.name = [f.path lastPathComponent];
    
    return f;
}

- (void)loadTextContents:(void (^)(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error))completion;
{
    NSParameterAssert(completion);
    NSAssert(!self.binary, nil);
    NSAssert(self.mode == DiffFileModeBlob || self.mode == DiffFileModeBlobExecutable, nil);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        git_blob *newBlob = NULL;
        git_blob *oldBlob = NULL;
        git_patch *gitPatch = NULL;
        __block git_buf patchBuf = {0};
        
        NSString *newText = nil;
        NSString *oldText = nil;
        NSString *patchText = nil;
        
        [_repo readLock];
        
        dispatch_block_t cleanup = ^{
            if (newBlob) git_blob_free(newBlob);
            if (oldBlob) git_blob_free(oldBlob);
            if (gitPatch) git_patch_free(gitPatch);
            if (patchBuf.ptr) git_buf_free(&patchBuf);
            
            [_repo unlock];
        };

        #define CHK(X) \
        do { \
            int giterr = (X); \
            if (giterr) { \
                cleanup(); \
                NSError *err = [NSError gitError]; \
                RunOnMain(^{ completion(nil, nil, nil, err); }); \
            } \
        } while(0);
        
        if (!git_oid_iszero(&_oldOid)) {
            CHK(git_blob_lookup(&oldBlob, _repo.repo, &_oldOid));
            oldText = [NSString stringWithGitBlob:oldBlob];
        }
        
        if (!git_oid_iszero(&_newOid)) {
            CHK(git_blob_lookup(&newBlob, _repo.repo, &_newOid));
            newText = [NSString stringWithGitBlob:newBlob];
        }
        
        CHK(git_patch_from_blobs(&gitPatch, oldBlob, NULL /*oldfilename*/, newBlob, NULL /*newfilename*/, NULL /* default diff options */));
        CHK(git_patch_to_buf(&patchBuf, gitPatch));
        patchText = [NSString stringWithGitBuf:&patchBuf];
        
        cleanup();
        
        RunOnMain(^{
            completion(oldText, newText, patchText, nil);
        });
    });
}

@end

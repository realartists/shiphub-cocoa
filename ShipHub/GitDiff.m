//
//  Diff.m
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GitDiffInternal.h"

#import "Extras.h"
#import "NSData+Git.h"
#import "NSError+Git.h"
#import "NSString+Git.h"
#import "GitRepoInternal.h"
#import "GitFileSearch.h"
#import <git2.h>

static NSRegularExpression *hunkStartRE();

@interface GitDiffFile ()

+ (GitDiffFile *)fileWithDelta:(const git_diff_delta *)delta inRepo:(GitRepo *)repo;

@property git_oid newOid;
@property git_oid oldOid;

@property NSString *path;
@property NSString *name;
@property NSString *oldPath;

@property DiffFileOperation operation;
@property DiffFileMode mode;
@property DiffFileMode oldMode;

@property (readwrite, weak) GitFileTree *parentTree;

@property GitRepo *repo;
@property (getter=isBinary) BOOL binary;

- (void)_loadContentsAsText:(GitDiffFileTextCompletion)textCompletion asBinary:(GitDiffFileBinaryCompletion)binaryCompletion completionQueue:(dispatch_queue_t)completionQueue;

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

#define CHK(X) \
    do { \
        int giterr = (X); \
        if (giterr) { \
            if (error) *error = [NSError gitError]; \
            cleanup(); \
            return nil; \
        } \
    } while (0);

+ (GitDiff *)diffWithRepo:(GitRepo *)repo from:(NSString *)baseRev to:(NSString *)headRev error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(repo);
    NSParameterAssert(baseRev);
    NSParameterAssert(headRev);
    
    [repo readLock];
    
    if (error) *error = nil;
    
    __block git_object *baseObj = NULL;
    __block git_object *headObj = NULL;
    __block git_commit *baseCommit = NULL;
    __block git_commit *headCommit = NULL;
    __block git_tree *baseTree = NULL;
    __block git_tree *headTree = NULL;
    
    dispatch_block_t cleanup = ^{
        if (baseObj) git_object_free(baseObj);
        if (headObj) git_object_free(headObj);
        if (baseCommit) git_commit_free(baseCommit);
        if (headCommit) git_commit_free(headCommit);
        if (baseTree) git_tree_free(baseTree);
        if (headTree) git_tree_free(headTree);
        [repo unlock];
    };
    
    CHK(git_revparse_single(&baseObj, repo.repo, [baseRev UTF8String]));
    CHK(git_revparse_single(&headObj, repo.repo, [headRev UTF8String]));
    
    CHK(git_commit_lookup(&baseCommit, repo.repo, git_object_id(baseObj)));
    CHK(git_commit_lookup(&headCommit, repo.repo, git_object_id(headObj)));
    
    CHK(git_commit_tree(&baseTree, baseCommit));
    CHK(git_commit_tree(&headTree, headCommit));
    
    NSError *diffErr = nil;
    GitDiff *result = [GitDiff diffWithRepo:repo fromTree:baseTree fromRev:baseRev toTree:headTree toRev:headRev error:&diffErr];
    
    if (diffErr && error) {
        *error = diffErr;
    }
    
    cleanup();
    
    return result;
}

+ (GitDiff *)diffWithRepo:(GitRepo *)repo fromMergeBaseOfStart:(NSString *)baseRev to:(NSString *)headRev error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(repo);
    NSParameterAssert(baseRev);
    NSParameterAssert(headRev);
    
    [repo readLock];
    
    if (error) *error = nil;
    
    __block git_object *baseObj = NULL;
    __block git_object *headObj = NULL;
    __block git_commit *mergeBaseCommit = NULL;
    __block git_commit *headCommit = NULL;
    __block git_tree *mergeBaseTree = NULL;
    __block git_tree *headTree = NULL;
    
    dispatch_block_t cleanup = ^{
        if (baseObj) git_object_free(baseObj);
        if (headObj) git_object_free(headObj);
        if (mergeBaseCommit) git_commit_free(mergeBaseCommit);
        if (headCommit) git_commit_free(headCommit);
        if (mergeBaseTree) git_tree_free(mergeBaseTree);
        if (headTree) git_tree_free(headTree);
        [repo unlock];
    };
    
    CHK(git_revparse_single(&baseObj, repo.repo, [baseRev UTF8String]));
    CHK(git_revparse_single(&headObj, repo.repo, [headRev UTF8String]));
    
    git_oid mergeBaseOid;
    CHK(git_merge_base(&mergeBaseOid, repo.repo, git_object_id(baseObj), git_object_id(headObj)));
    
    CHK(git_commit_lookup(&mergeBaseCommit, repo.repo, &mergeBaseOid));
    CHK(git_commit_lookup(&headCommit, repo.repo, git_object_id(headObj)));
    
    CHK(git_commit_tree(&mergeBaseTree, mergeBaseCommit));
    CHK(git_commit_tree(&headTree, headCommit));
    
    NSError *diffErr = nil;
    GitDiff *result = [GitDiff diffWithRepo:repo fromTree:mergeBaseTree fromRev:baseRev toTree:headTree toRev:headRev error:&diffErr];
    
    if (diffErr && error) {
        *error = diffErr;
    }
    
    cleanup();
    
    return result;
}

+ (GitDiff *)diffWithRepo:(GitRepo *)repo fromTree:(git_tree *)baseTree fromRev:(NSString *)baseRev toTree:(git_tree *)headTree toRev:(NSString *)headRev error:(NSError *__autoreleasing *)error
{
    __block git_diff *diff = NULL;
    
    dispatch_block_t cleanup = ^{
        if (diff) git_diff_free(diff);
    };
    
    CHK(git_diff_tree_to_tree(&diff, repo.repo, baseTree, headTree, NULL));
    
    git_diff_find_options opts = GIT_DIFF_FIND_OPTIONS_INIT;
    opts.flags = GIT_DIFF_FIND_RENAMES;
    CHK(git_diff_find_similar(diff, &opts));
    
    NSMutableArray *files = [NSMutableArray new];
    NSDictionary *info = @{@"files":files, @"repo":repo};
    CHK(git_diff_foreach(diff, fileVisitor, NULL /*binary cb*/, NULL /*hunk cb*/, NULL /*line cb*/, (__bridge void *)info));
    
    GitDiff *result = [[GitDiff alloc] initWithFiles:files baseRev:baseRev headRev:headRev];
    
    cleanup();
    
    return result;
}

+ (GitDiff *)emptyDiffAtRev:(NSString *)rev {
    GitDiff *diff = [[GitDiff alloc] initWithFiles:@[] baseRev:rev headRev:rev];
    return diff;
}

#undef CHK

- (id)initWithFiles:(NSArray *)files baseRev:(NSString *)baseRev headRev:(NSString *)headRev {
    if (self = [super init]) {
        self.baseRev = baseRev;
        self.headRev = headRev;
        self.allFiles = files;
        [self buildFileTree];
    }
    return self;
}

- (void)buildFileTree {
    /*
     This method builds a file tree, suitable for presentation to the user.
    */
     
    NSArray *pathSorted = [_allFiles sortedArrayUsingComparator:^NSComparisonResult(GitDiffFile *a, GitDiffFile *b) {
        return [a.path localizedStandardCompare:b.path];
    }];
    
    GitFileTree *root = [GitFileTree new];
    NSMutableDictionary *parents = [NSMutableDictionary new];
    parents[@""] = root;
    
    for (GitDiffFile *file in pathSorted) {
        // ensure parents
        id lastItem = file;
        NSString *pp = file.path;
        do {
            pp = [pp stringByDeletingLastPathComponent];
            GitFileTree *ancestor = parents[pp];
            id nextAncestor = nil;
            if (!ancestor) {
                ancestor = [GitFileTree new];
                ancestor.path = pp;
                ancestor.dirname = [pp lastPathComponent];
                parents[pp] = ancestor;
                nextAncestor = ancestor;
            }
            [ancestor.mutableChildren addObject:lastItem];
            [lastItem setParentTree:ancestor];
            lastItem = nextAncestor;
        } while ([pp length] && lastItem);
    }
    
    self.fileTree = root;
}

- (GitDiff *)copyByFilteringFilesWithPredicate:(NSPredicate *)predicate {
    return [[GitDiff alloc] initWithFiles:[self.allFiles filteredArrayUsingPredicate:predicate] baseRev:self.baseRev headRev:self.headRev];
}

static NSArray<GitFileSearchResult *> *_searchFile(NSRegularExpression *re, GitDiffFile *file, NSString *newContents) {
    __block NSMutableArray *results;
    __block NSInteger lineNumber = 0;
    
    [newContents enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        NSArray *matches = [re matchesInString:line options:0 range:NSMakeRange(0, line.length)];
        if (matches.count) {
            GitFileSearchResult *result = [GitFileSearchResult new];
            result.file = file;
            result.matchedResults = matches;
            result.matchedLineNumber = lineNumber;
            result.matchedLineText = line;
            if (!results) {
                results = [NSMutableArray new];
            }
            [results addObject:result];
        }
        lineNumber++;
    }];
    
    return results;
}

static NSArray<GitFileSearchResult *> *_searchDiff(NSRegularExpression *re, GitDiffFile *file, NSString *patch) {
    NSRegularExpression *hunkStart = hunkStartRE();

    __block NSMutableArray *results = nil;
    __block NSInteger lineNumber = -1;

    [patch enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
        NSTextCheckingResult *match = [hunkStart firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        
        if (lineNumber == -1 && !match) {
            // continue, need to get to the first hunk start before we can do anything
        } else if (match) {
            NSRange gr3 = [match rangeAtIndex:3];
            
            NSInteger rightStartLine = gr3.location != NSNotFound ? [[line substringWithRange:gr3] integerValue] : 1;
            lineNumber = rightStartLine - 1; // 0 index our line number
        } else if ([line hasPrefix:@"-"]) {
            // continue, don't care about deleted lines here
        } else if ([line hasPrefix:@" "]) {
            // context line, don't search it, but need to increment lineNumber
            lineNumber++;
        } else {
            // a searchable line
            NSString *subline = [line substringFromIndex:1];
            NSArray *matches = [re matchesInString:subline options:0 range:NSMakeRange(0, subline.length)];
            if (matches.count) {
                GitFileSearchResult *result = [GitFileSearchResult new];
                result.file = file;
                result.matchedResults = matches;
                result.matchedLineNumber = lineNumber;
                result.matchedLineText = subline;
                if (!results) {
                    results = [NSMutableArray new];
                }
                [results addObject:result];
            }
            lineNumber++;
        }
    }];
    
    return results;
}

- (NSProgress *)performTextSearch:(GitFileSearch *)search handler:(void (^)(NSArray<GitFileSearchResult *> *result))handler {
    // Concurrent processing in 2 parallel pipelines:
    //   Load: read contents of GitDiffFiles from git
    //   Search: search contents of files
    // Finished when there are no more active load or search jobs
    
    dispatch_queue_t callbackQ = dispatch_get_main_queue();
    dispatch_queue_t workQ = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_queue_t progressQueue = dispatch_queue_create(NULL, NULL);
    __block NSInteger completed = 0;
    
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:_allFiles.count];
    
    BOOL searchDiffOnly = (search.flags & GitFileSearchFlagAddedLinesOnly) != 0;
    
    NSString *pattern;
    if (search.flags & GitFileSearchFlagRegex) {
        pattern = search.query;
    } else {
        pattern = [NSRegularExpression escapedPatternForString:search.query];
    }
    
    NSRegularExpressionOptions reOpts = 0;
    reOpts |= (search.flags & GitFileSearchFlagCaseInsensitive) ? NSRegularExpressionCaseInsensitive : 0;
    
    NSError *reError = nil;
    NSRegularExpression *re = [[NSRegularExpression alloc] initWithPattern:pattern options:reOpts error:&reError];
    
    if (reError) {
        DebugLog(@"Cannot make regular expression: %@", reError);
        dispatch_async(callbackQ, ^{
            handler(nil);
        });
    }
    
    void (^handlerProxy)(NSArray<GitFileSearchResult *> *) = ^(NSArray<GitFileSearchResult *> *result) {
        if (!progress.cancelled) {
            handler(result);
        }
    };
    
    dispatch_block_t incrementProgress = ^{
        dispatch_sync(progressQueue, ^{
            progress.completedUnitCount = ++completed;
        });
    };
    
    dispatch_async(workQ, ^{
        dispatch_group_t group = dispatch_group_create(); // tracks completion
        
        for (GitDiffFile *file in _allFiles) {
            if (progress.cancelled) break;
            
            dispatch_group_enter(group);
            [file _loadContentsAsText:^(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error) {
                if (!progress.cancelled) {
                    dispatch_group_async(group, workQ, ^{
                        NSArray *fileResults;
                        if (searchDiffOnly) {
                            fileResults = _searchDiff(re, file, patch);
                        } else {
                            fileResults = _searchFile(re, file, newFile);
                        }
                        for (GitFileSearchResult *result in fileResults) {
                            result.search = search;
                        }
                        
                        if ([fileResults count]) {
                            dispatch_async(callbackQ, ^{
                                handlerProxy(fileResults);
                            });
                        }
                        incrementProgress();
                    });
                }
                dispatch_group_leave(group); // pair the initial load
            } asBinary:^(NSData *oldFile, NSData *newFile, NSError *error) {
                incrementProgress();
                dispatch_group_leave(group); // we don't search binary files
            } completionQueue:workQ];
        }
        
        dispatch_group_notify(group, callbackQ, ^{
            handlerProxy(nil);
        });
    });
    
    return progress;
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
    f.oldMode = delta->old_file.mode;
    if (f.mode == DiffFileModeUnreadable) { /* deleted in new */
        f.mode = (DiffFileMode)delta->old_file.mode;
    }
    f.operation = (DiffFileOperation)delta->status;
    f.name = [f.path lastPathComponent];
    
    return f;
}

- (BOOL)isSubmodule {
    return self.mode == DiffFileModeCommit;
}

- (void)_loadContentsAsText:(GitDiffFileTextCompletion)textCompletion asBinary:(GitDiffFileBinaryCompletion)binaryCompletion completionQueue:(dispatch_queue_t)completionQueue
{
    NSParameterAssert(textCompletion);
    NSParameterAssert(binaryCompletion);
    NSParameterAssert(completionQueue);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block git_submodule *submodule = NULL;
        __block git_blob *newBlob = NULL;
        __block git_blob *oldBlob = NULL;
        __block git_patch *gitPatch = NULL;
        __block git_buf patchBuf = {0};
        
        NSString *newText = nil;
        NSString *oldText = nil;
        NSString *patchText = nil;
        
        NSData *newData = nil;
        NSData *oldData = nil;
        
        [_repo readLock];
        
        dispatch_block_t cleanup = ^{
            if (submodule) git_submodule_free(submodule);
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
                RunOnMain(^{ textCompletion(nil, nil, nil, err); }); \
                return; \
            } \
        } while(0);
        
        BOOL isSubmodule = self.mode == DiffFileModeCommit;
        
        if (isSubmodule) {
            NSMutableString *patch = [NSMutableString new];
            
            // add
            /*
             diff --git a/web b/web
             new file mode 160000
             index 0000000..6fef966
             --- /dev/null
             +++ b/web
             @@ -0,0 +1 @@
             +6fef96688f06f620235b0e7617d6bbbe8e451d60
             */
            
            // update
            /*
             diff --git a/web b/web
             index 6fef966..5eda0b7 160000
             --- a/web
             +++ b/web
             @@ -1 +1 @@
             -Subproject commit 6fef96688f06f620235b0e7617d6bbbe8e451d60
             +Subproject commit 5eda0b7902a0e0ac6320e57444779d154b7915a7
             */
            
            // delete
            /*
             diff --git a/web b/web
             deleted file mode 160000
             index 5eda0b7..0000000
             --- a/web
             +++ /dev/null
             @@ -1 +0,0 @@
             -Subproject commit 5eda0b7902a0e0ac6320e57444779d154b7915a7
             */
            
            BOOL add = git_oid_iszero(&_oldOid);
            BOOL delete = git_oid_iszero(&_newOid);
            
            [patch appendFormat:@"diff --git a/%@ b/%@\n", self.oldPath, self.path];
            char bufOld[8];
            char bufNew[8];
            [patch appendFormat:@"index %s..%s\n", git_oid_tostr(bufOld, 8, &_oldOid), git_oid_tostr(bufNew, 8, &_newOid)];
            [patch appendFormat:@"--- %@\n", add?@"/dev/null":[@"a/" stringByAppendingString:self.oldPath]];
            [patch appendFormat:@"+++ %@\n", delete?@"/dev/null":[@"b/" stringByAppendingString:self.path]];
            if (add) {
                [patch appendString:@"@@ -0,0 +1 @@\n"];
            } else if (delete) {
                [patch appendString:@"@@ -1 +0,0 @@\n"];
            } else /* update */ {
                [patch appendString:@"@@ -1 +1 @@\n"];
            }
            
            if (!git_oid_iszero(&_oldOid)) {
                oldText = [NSString stringWithGitOid:&_oldOid];
                [patch appendFormat:@"-%@\n", oldText];
            } else {
                oldText = @"";
            }
            
            if (!git_oid_iszero(&_newOid)) {
                newText = [NSString stringWithGitOid:&_newOid];
                [patch appendFormat:@"+%@\n", newText];
            } else {
                newText = @"";
            }
            
            patchText = [NSString stringWithString:patch];
            
            dispatch_async(completionQueue, ^{
                textCompletion(oldText, newText, patchText, nil);
            });
        } else {
            BOOL binary = self.binary; // this is not necessarily accurate, yet, we may have to look at the contents to figure out.
            
            if (!git_oid_iszero(&_oldOid)) {
                CHK(git_blob_lookup(&oldBlob, _repo.repo, &_oldOid));
                binary = binary || git_blob_is_binary(oldBlob);
            }
            
            if (!git_oid_iszero(&_newOid)) {
                CHK(git_blob_lookup(&newBlob, _repo.repo, &_newOid));
                binary = binary || git_blob_is_binary(newBlob);
            }
            
            if (oldBlob) {
                if (binary) {
                    oldData = [NSData dataWithGitBlob:oldBlob];
                } else {
                    oldText = [NSString stringWithGitBlob:oldBlob];
                }
            }
            
            if (newBlob) {
                if (binary) {
                    newData = [NSData dataWithGitBlob:newBlob];
                } else {
                    newText = [NSString stringWithGitBlob:newBlob];
                }
            }
            
            if (!binary) {
                CHK(git_patch_from_blobs(&gitPatch, oldBlob, NULL /*oldfilename*/, newBlob, NULL /*newfilename*/, NULL /* default diff options */));
                CHK(git_patch_to_buf(&patchBuf, gitPatch));
                patchText = [NSString stringWithGitBuf:&patchBuf];
            }
            
            dispatch_async(completionQueue, ^{
                if (binary) {
                    binaryCompletion(oldData, newData, nil);
                } else {
                    textCompletion(oldText, newText, patchText, nil);
                }
            });
        }
        
        cleanup();
        
        #undef CHK
    });
}

- (void)loadContentsAsText:(GitDiffFileTextCompletion)textCompletion asBinary:(GitDiffFileBinaryCompletion)binaryCompletion
{
    [self _loadContentsAsText:textCompletion asBinary:binaryCompletion completionQueue:dispatch_get_main_queue()];
}

static BOOL matchingHunkStart(NSString *a, NSString *b) {
    NSRegularExpression *re = hunkStartRE();
    
    NSTextCheckingResult *ma = [re firstMatchInString:a options:0 range:NSMakeRange(0, a.length)];
    if (!ma) return NO;
    NSTextCheckingResult *mb = [re firstMatchInString:b options:0 range:NSMakeRange(0, b.length)];
    if (!mb) return NO;
    
    NSRange aRange[5];
    NSRange bRange[5];
    
    for (NSInteger i = 0; i < 5; i++) {
        aRange[i] = [ma rangeAtIndex:i];
        bRange[i] = [mb rangeAtIndex:i];
    }
    
    NSInteger aLeftRun, aRightRun;
    NSInteger bLeftRun, bRightRun;
    
    aLeftRun = aRange[2].location != NSNotFound ? [[a substringWithRange:aRange[2]] integerValue] : 1;
    bLeftRun = bRange[2].location != NSNotFound ? [[b substringWithRange:bRange[2]] integerValue] : 1;
    aRightRun = aRange[4].location != NSNotFound ? [[a substringWithRange:aRange[4]] integerValue] : 1;
    bRightRun = bRange[4].location != NSNotFound ? [[b substringWithRange:bRange[4]] integerValue] : 1;
    
    return aLeftRun == bLeftRun && aRightRun == bRightRun;
}

static BOOL matchingHunks(NSArray *aLines, NSArray *bLines, NSInteger aIdx, NSInteger bIdx, NSInteger aLineCount, NSInteger bLineCount, NSInteger *aAdvance, NSInteger *bAdvance, NSRange *aMatchRange, NSRange *bMatchRange)
{
    *aAdvance = 1;
    *bAdvance = 0;
    
    *aMatchRange = NSMakeRange(NSNotFound, 0);
    *bMatchRange = NSMakeRange(NSNotFound, 0);
    
    NSInteger aSave = aIdx;
    NSInteger bSave = bIdx;
    
    while (bIdx < bLineCount) {
        aIdx = aSave;
        if (![bLines[bIdx] hasPrefix:@"@@"]) {
            bIdx++;
        } else if (matchingHunkStart(aLines[aIdx], bLines[bIdx])) {
            aMatchRange->location = aIdx;
            bMatchRange->location = bIdx;
            
            aIdx++;
            bIdx++;
            
            // we have a matching hunk start.
            // now find out if the hunks match exactly.
            while (1)
            {
                if ((aIdx == aLineCount || [aLines[aIdx] length] == 0 || [aLines[aIdx] hasPrefix:@"@@"])
                    && (bIdx == bLineCount || [bLines[bIdx] length] == 0 || [bLines[bIdx] hasPrefix:@"@@"]))
                {
                    // we've matched the whole hunk
                    *aAdvance = aIdx - aSave;
                    *bAdvance = bIdx - bSave;
                    
                    aMatchRange->length = aIdx - aMatchRange->location;
                    bMatchRange->length = bIdx - bMatchRange->location;
                    
                    return YES;
                } else if ([aLines[aIdx] isEqualToString:bLines[bIdx]]) {
                    // we're making progress
                    aIdx++;
                    bIdx++;
                } else {
                    // this hunk is not a match, go on to the next hunk in b
                    bIdx++;
                    break;
                }
            }
        } else {
            bIdx++;
        }
    }
    
    return NO;
}

static NSArray *patchMapping(NSString *a, NSString *b) {
    NSArray *aLines = [a componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    NSArray *bLines = [b componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    NSInteger aLineCount = [aLines count];
    NSInteger bLineCount = [bLines count];
    if (!aLineCount) {
        return @[];
    }
    
    NSInteger aIdx = 0, bIdx = 0;
    
    NSMutableArray *map = [NSMutableArray arrayWithCapacity:[aLines count]];
    
    // initialize map with no mapping sentinel value -1 at
    // every position.
    for (NSUInteger i = 0; i < aLineCount; i++) {
        [map addObject:@(-1)];
    }
    
    // walk to the first hunk of the diff. assume the headers are equivalent-ish
    while (aIdx < aLineCount && ![aLines[aIdx] hasPrefix:@"@@"]
           && bIdx < bLineCount && ![bLines[bIdx] hasPrefix:@"@@"])
    {
        map[aIdx] = @(bIdx);
        aIdx++;
        bIdx++;
    }
    
    // for each hunk in a, see if we can find it in b
    while (aIdx < aLineCount) {
        if ([aLines[aIdx] hasPrefix:@"@@"]) {
            NSInteger aAdvance, bAdvance;
            NSRange aMatchRange, bMatchRange;
            
            if (matchingHunks(aLines, bLines, aIdx, bIdx, aLineCount, bLineCount, &aAdvance, &bAdvance, &aMatchRange, &bMatchRange)) {
                for (NSInteger aMap = aMatchRange.location, bMap = bMatchRange.location, m = 0; m < aMatchRange.length; aMap++, bMap++, m++)
                {
                    map[aMap] = @(bMap);
                }
                aIdx += aAdvance;
                bIdx += bAdvance;
            } else {
                // there was no hunk in b that could match the hunk starting at aIdx
                // leave bIdx where it was and bump aIdx
                aIdx++;
            }
        } else {
            aIdx++; // skip this line in a
        }
    }
    
    return map;
}

+ (void)computePatchMappingFromPatch:(NSString *)patch toPatchForFile:(GitDiffFile *)spanDiffFile completion:(void (^)(NSArray *mapping))completion
{
    NSParameterAssert(patch);
    NSParameterAssert(completion);
    
    if (!spanDiffFile) {
        NSInteger lineCount = [[patch componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] count];
        NSMutableArray *map = [NSMutableArray arrayWithCapacity:lineCount];
        for (NSUInteger i = 0; i < lineCount; i++) {
            [map addObject:@(-1)];
        }
        completion(map);
    } else {
        [spanDiffFile loadContentsAsText:^(NSString *a, NSString *b, NSString *spanPatch, NSError *error) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
                NSArray *mapping = patchMapping(patch, spanPatch);
                
                RunOnMain(^{
                    completion(mapping);
                });
                
            });
        } asBinary:^(NSData *oldFile, NSData *newFile, NSError *error) {
            NSAssert(NO, @"Should not try to compute patch mapping on binary file");
            completion(nil);
        }];
    }
}

@end

static NSRegularExpression *hunkStartRE() {
    static dispatch_once_t onceToken;
    static NSRegularExpression *re;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"^@@ \\-(\\d+)(?:,(\\d+))? \\+(\\d+)(?:,(\\d+))? @@" options:0 error:NULL];
    });
    return re;
}

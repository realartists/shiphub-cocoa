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

+ (GitDiff *)diffWithRepo:(GitRepo *)repo fromTree:(git_tree *)baseTree fromRev:(NSString *)baseRev toTree:(git_tree *)headTree toRev:(NSString *)headRev error:(NSError *__autoreleasing *)error
{
    __block git_diff *diff = NULL;
    
    dispatch_block_t cleanup = ^{
        if (diff) git_diff_free(diff);
    };
    
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

- (void)loadContentsAsText:(GitDiffFileTextCompletion)textCompletion asBinary:(GitDiffFileBinaryCompletion)binaryCompletion
{
    NSParameterAssert(textCompletion);
    NSParameterAssert(binaryCompletion);
    NSAssert(self.mode == DiffFileModeBlob || self.mode == DiffFileModeBlobExecutable, nil);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
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
            } \
        } while(0);
        
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
        
        cleanup();
        
        RunOnMain(^{
            if (binary) {
                binaryCompletion(oldData, newData, nil);
            } else {
                textCompletion(oldText, newText, patchText, nil);
            }
        });
        
        #undef CHK
    });
}

static BOOL matchingHunkStart(NSString *a, NSString *b) {
    static dispatch_once_t onceToken;
    static NSRegularExpression *re;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"^@@ \\-(\\d+)(?:,(\\d+))? \\+(\\d+)(?:,(\\d+))? @@" options:0 error:NULL];
    });
    
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
        NSString *aLine = aLines[aIdx];
        
        if ([aLine hasPrefix:@"@@"]) {
            NSInteger bSave = bIdx;
            
            // see if we can find a matching hunk header in b
            while (bIdx < bLineCount && !matchingHunkStart(aLine, bLines[bIdx])) bIdx++;
            
            if (bIdx != bLineCount) {
                // found candidate hunk match in b
                // walk a and b forward to see if we can match all the way
                
                NSInteger aSave = aIdx;
                
                while (aIdx < aLineCount
                       && bIdx < bLineCount
                       && [aLines[aIdx] isEqualToString:bLines[bIdx]]) {
                    aIdx++;
                    bIdx++;
                }
                
                if (((aIdx < aLineCount && [aLines[aIdx] hasPrefix:@"@@"]) || aIdx == aLineCount)
                    && ((bIdx < bLineCount && [bLines[bIdx] hasPrefix:@"@@"]) || bIdx == bLineCount))
                {
                    // preceding hunk from aSave to aIdx is a match. map it.
                    for (NSInteger aMap = aSave, bMap = bSave; aMap < aIdx; aMap++, bMap++) {
                        map[aMap] = @(bMap);
                    }
                } else {
                    // couldn't find a match in b for the hunk in a.
                    // restore bIdx to allow for re-searching this hunk in b again.
                    // meanwhile, aIdx is advanced past this hunk in a.
                    bIdx = bSave;
                }
                
            } else {
                // couldn't find a match. this hunk in a is unmatcheable. skip it.
                while (aIdx < aLineCount && [aLines[aIdx] hasPrefix:@"@@"]) aIdx++;
                
                // reset bIdx to where it was.
                bIdx = bSave;
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

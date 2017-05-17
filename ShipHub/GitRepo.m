//
//  GitRepo.m
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GitRepoInternal.h"

#import "Extras.h"
#import "NSError+Git.h"

#import <pthread.h>

@interface GitRepo () {
    pthread_rwlock_t _rwlock;
}

@property git_repository *repo;
@property NSArray *fetchingRefs;

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

/**
 * Signature of a function which acquires a credential object.
 *
 * - cred: The newly created credential object.
 * - url: The resource for which we are demanding a credential.
 * - username_from_url: The username that was embedded in a "user\@host"
 *                          remote url, or NULL if not included.
 * - allowed_types: A bitmask stating which cred types are OK to return.
 * - payload: The payload provided when specifying this callback.
 * - returns 0 for success, < 0 to indicate an error, > 0 to indicate
 *       no credential was acquired
 */
static int credentialsCallback(git_cred **cred,
                               const char *url,
                               const char *username_from_url,
                               unsigned int allowed_types,
                               void *payload)
{
    NSDictionary *info = (__bridge NSDictionary *)payload;
    return git_cred_userpass_plaintext_new(cred, [info[@"username"] UTF8String], [info[@"password"] UTF8String]);
}

static int progressCallback(const git_transfer_progress *stats, void *payload) {
    NSDictionary *info = (__bridge NSDictionary *)payload;
    NSProgress *progress = info[@"progress"];
    if ([progress isCancelled]) {
        return -1;
    }
    
    progress.totalUnitCount = (NSInteger)stats->total_objects;
    progress.completedUnitCount = (NSInteger)stats->received_objects;
    return 0;
}


static int updateRefs(const char *ref_name, const char *remote_url, const git_oid *oid, unsigned int is_merge, void *payload) {
    GitRepo *repo = (__bridge GitRepo *)payload;
    
    NSArray *fetchRefs = repo.fetchingRefs;
    
    for (NSString *candidateRef in fetchRefs) {
        if (strcmp(ref_name, [[@"refs/" stringByAppendingString:candidateRef] UTF8String]) == 0) {
            git_reference *newRef = NULL;
            int ret = git_reference_create(&newRef, repo.repo, ref_name, oid, 1, "fetch");
            if (newRef) git_reference_free(newRef);
            return ret;
        }
    }
    
    return 0;
}

- (NSError *)fetchRemote:(NSURL *)remoteURL username:(NSString *)username password:(NSString *)password refs:(NSArray *)refs progress:(NSProgress *)progress
{
    [self writeLock];
    
    _fetchingRefs = refs;
    
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
        _fetchingRefs = nil;
        [self unlock];
    };
    
#define CHK(X) \
    do { \
        int giterr = (X); \
        if (progress.cancelled) { \
            cleanup(); \
            return [NSError cancelError]; \
        } else if (giterr) { \
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
    
    git_remote_lookup(&remote, _repo, "github");
    if (!remote) {
        git_remote_create(&remote,
                          _repo,
                          "github",
                          [[remoteURL description] UTF8String]);
    }
    
    NSDictionary *payload = @{ @"username": username, @"password": password, @"progress" : progress };
    
    git_fetch_options opts = {
        .version = GIT_FETCH_OPTIONS_VERSION,
        .callbacks =
        {
            .version = GIT_REMOTE_CALLBACKS_VERSION,
            .sideband_progress = NULL,
            .completion = NULL,
            .credentials = credentialsCallback,
            .certificate_check = NULL,
            .transfer_progress = progressCallback,
            .update_tips = NULL,
            .pack_progress = NULL,
            .push_transfer_progress = NULL,
            .push_update_reference = NULL,
            .push_negotiation = NULL,
            .transport = NULL,
            .payload = (__bridge void *)payload,
        },
        .prune = GIT_FETCH_NO_PRUNE,
        .update_fetchhead = 1,
        .download_tags = GIT_REMOTE_DOWNLOAD_TAGS_NONE,
        .custom_headers = { NULL, 0 }
    };
    
    CHK(git_remote_fetch(remote, &refspecs, &opts, NULL /*reflogs msg*/));
    
    // we have to use FETCH_HEAD now to locally add a named ref to each ref
    // (why git doesn't do this automatically or have an option to do it automatically is beyond me)
    git_repository_fetchhead_foreach(_repo, updateRefs, (__bridge void *)self);
    
    cleanup();
    return nil;
}

- (NSError *)pushRemote:(NSURL *)remoteURL username:(NSString *)username password:(NSString *)password newBranchWithProposedName:(NSString *)branchName revertingCommit:(NSString *)mergeCommitSha fromBranch:(NSString *)sourceBranch progress:(NSProgress *)progress
{
    [self writeLock];
    
    __block git_remote *remote = NULL;
    __block git_commit *mergeCommit = NULL;
    __block git_commit *sourceBranchHeadCommit = NULL;
    __block git_index *revertIdx = NULL;
    __block git_reference *newBranch = NULL;
    __block git_tree *revertTree = NULL;
    __block git_signature *authorSig = NULL;
    __block git_signature *committerSig = NULL;
    __block git_strarray refspecs = {0};
    
    git_oid branchHeadOid;
    git_oid mergeCommitOid;
    git_oid revertTreeOid;
    git_oid revertCommitOid;
    
    dispatch_block_t cleanup = ^{
        if (remote) git_remote_free(remote);
        if (sourceBranchHeadCommit) git_commit_free(sourceBranchHeadCommit);
        if (mergeCommit) git_commit_free(mergeCommit);
        if (revertIdx) git_index_free(revertIdx);
        if (newBranch) git_reference_free(newBranch);
        if (revertTree) git_tree_free(revertTree);
        if (authorSig) git_signature_free(authorSig);
        if (committerSig) git_signature_free(committerSig);
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
        if (progress.cancelled) { \
            cleanup(); \
            return [NSError cancelError]; \
        } else if (giterr) { \
            NSError *err = [NSError gitError]; \
            cleanup(); \
            return err; \
        } \
    } while (0);

    // make sure that we have the github remote.
    // this just asserts that fetch has run.
    CHK(git_remote_lookup(&remote, _repo, "github"));
    
    CHK(git_reference_name_to_id(&branchHeadOid, _repo, [[NSString stringWithFormat:@"refs/remotes/github/%@", sourceBranch] UTF8String]));
    CHK(git_commit_lookup(&sourceBranchHeadCommit, _repo, &branchHeadOid));
    
    // see if we can find mergeCommit
    CHK(git_oid_fromstrp(&mergeCommitOid, [mergeCommitSha UTF8String]));
    CHK(git_commit_lookup_prefix(&mergeCommit, _repo, &mergeCommitOid, [mergeCommitSha length]));
    
    // create an in memory index reverting mergeCommit
    CHK(git_revert_commit(&revertIdx, _repo, mergeCommit, sourceBranchHeadCommit, 1, NULL));
    
    // try to write the index to the repo
    CHK(git_index_write_tree_to(&revertTreeOid, revertIdx, _repo));
    
    CHK(git_tree_lookup(&revertTree, _repo, &revertTreeOid));
    
    // delete the branch if it already exists
    git_branch_lookup(&newBranch, _repo, [branchName UTF8String], GIT_BRANCH_LOCAL);
    if (newBranch) {
        CHK(git_branch_delete(newBranch));
        newBranch = NULL;
    }
    
    // create the branch
    CHK(git_branch_create(&newBranch, _repo, [branchName UTF8String], sourceBranchHeadCommit, 0));
    
    if (0 != git_signature_default(&authorSig, _repo)) {
        CHK(git_signature_dup(&authorSig, git_commit_author(mergeCommit)));
        authorSig->when.offset = (int)([[NSTimeZone localTimeZone] secondsFromGMT] / 60);
        authorSig->when.time = [[NSDate date] timeIntervalSince1970];
    }
    if (0 != git_signature_default(&committerSig, _repo)) {
        CHK(git_signature_dup(&committerSig, git_commit_committer(mergeCommit)));
        committerSig->when.offset = (int)([[NSTimeZone localTimeZone] secondsFromGMT] / 60);
        committerSig->when.time = [[NSDate date] timeIntervalSince1970];
    }
    
    // write the revert index as a commit to newBranch
    CHK(git_commit_create(&revertCommitOid,
                          _repo,
                          [[NSString stringWithFormat:@"refs/heads/%@", branchName] UTF8String],
                          git_commit_author(mergeCommit),
                          git_commit_committer(mergeCommit),
                          "UTF8",
                          [[NSString stringWithFormat:@"Revert %s", git_commit_message(mergeCommit)?:"merge commit"] UTF8String],
                          revertTree,
                          1,
                          (const git_commit **)&mergeCommit));
    
    // build refspecs to push
    refspecs.strings = malloc(sizeof(char *) * 1);
    refspecs.count = 1;
    refspecs.strings[0] = strdup([[NSString stringWithFormat:@"+refs/heads/%@", branchName] UTF8String]);
    
    NSDictionary *payload = @{ @"username": username, @"password": password, @"progress" : progress };
    
    git_push_options opts = {
        .version = GIT_PUSH_OPTIONS_VERSION,
        .pb_parallelism = 0,
        .callbacks = {
            .version = GIT_REMOTE_CALLBACKS_VERSION,
            .sideband_progress = NULL,
            .completion = NULL,
            .credentials = credentialsCallback,
            .certificate_check = NULL,
            .transfer_progress = progressCallback,
            .update_tips = NULL,
            .pack_progress = NULL,
            .push_transfer_progress = NULL,
            .push_update_reference = NULL,
            .push_negotiation = NULL,
            .transport = NULL,
            .payload = (__bridge void *)payload,
        }
    };
    
    CHK(git_remote_push(remote, &refspecs, &opts));
    
    cleanup();
    return nil;
    
#undef CHK
}

- (BOOL)hasRef:(NSString *)refName error:(NSError *__autoreleasing *)outError
{
    if (outError) *outError = nil;
    
    [self writeLock];
    
    __block git_reference *ref = NULL;
    
    int result = git_reference_lookup(&ref, _repo, [refName UTF8String]);
    
    if (result != GIT_ENOTFOUND && result != 0) {
        if (outError) {
            *outError = [NSError gitError];
        }
    }
    
    return result == 0;
}

- (NSError *)updateRef:(NSString *)refName toSha:(NSString *)sha {
    [self writeLock];
    
    NSString *fullName = [NSString stringWithFormat:@"refs/%@", refName];
    
    __block git_commit *commit = NULL;
    __block git_reference *ref = NULL;

    git_oid oid = {0};
    git_oid refOid = {0};
    
    dispatch_block_t cleanup = ^{
        if (commit) git_commit_free(commit);
        if (ref) git_reference_free(ref);
        
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
    
    CHK(git_oid_fromstr(&oid, [sha UTF8String]));
    
    if (0 == git_reference_name_to_id(&refOid, _repo, [fullName UTF8String]) && 0 == git_oid_cmp(&oid, &refOid))
    {
        // all set.
        cleanup();
        return nil;
    }
    
    // still here? ok, we gotta update it.
    
    CHK(git_commit_lookup(&commit, _repo, &oid));
    
    CHK(git_reference_create(&ref, _repo, [fullName UTF8String], &oid, 1, "update"));
    
    cleanup();
    return nil;
}

@end

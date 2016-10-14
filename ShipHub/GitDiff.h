//
//  Diff.h
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GitCommit;
@class GitRepo;

typedef NS_ENUM(NSInteger, DiffFileOperation) {
    DiffFileOperationAdded = 1,
    DiffFileOperationDeleted = 2,
    DiffFileOperationModified = 3,
    DiffFileOperationRenamed = 4,
    DiffFileOperationCopied = 5,
    DiffFileOperationTypeChange = 8,
    DiffFileOperationTypeConflicted = 10
};

typedef NS_ENUM(NSInteger, DiffFileMode) {
    DiffFileModeUnreadable          = 0000000,
    DiffFileModeTree                = 0040000,
    DiffFileModeBlob                = 0100644,
    DiffFileModeBlobExecutable      = 0100755,
    DiffFileModeLink                = 0120000,
    DiffFileModeCommit              = 0160000,
};

@interface GitDiffFile : NSObject

@property (readonly) NSString *name;
@property (readonly) NSString *path;
@property (readonly) NSString *oldPath; // if copied or renamed

@property (readonly, getter=isBinary) BOOL binary;

@property (readonly) DiffFileOperation operation;
@property (readonly) DiffFileMode mode;

// Only valid if not binary and mode is Blob or BlobExecutable
- (void)loadTextContents:(void (^)(NSString *oldFile, NSString *newFile, NSString *patch, NSError *error))completion;

@end

@interface GitFileTree : NSObject

@property (readonly) NSString *name;
@property (readonly) NSString *dirname;
@property (readonly) NSString *path;
@property (readonly) NSArray /*either GitFileTree or GitFile*/ *children;

@end

@interface GitDiff : NSObject

+ (GitDiff *)diffWithRepo:(GitRepo *)repo from:(NSString *)baseRev to:(NSString *)headRev error:(NSError *__autoreleasing *)error;

@property (readonly) NSArray<GitDiffFile *> *allFiles;

// Returns a sorted, hierarchical listing of files.
@property (readonly) GitFileTree *fileTree;

@end

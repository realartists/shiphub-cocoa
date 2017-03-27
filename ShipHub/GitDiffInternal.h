//
//  GitDiffInternal.h
//  ShipHub
//
//  Created by James Howard on 3/23/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "GitDiff.h"

#import <git2.h>

@interface GitDiff (Internal)

// Create a GitDiff between two trees.
// Lock on repo should already be held by the caller.
+ (GitDiff *)diffWithRepo:(GitRepo *)repo fromTree:(git_tree *)baseTree fromRev:(NSString *)baseRev toTree:(git_tree *)headTree toRev:(NSString *)headRev error:(NSError *__autoreleasing *)error;

@end

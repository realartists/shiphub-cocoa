//
//  GitRepoInternal.h
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "GitRepo.h"

#import <git2.h>

@interface GitRepo (Internal)

@property (readonly) git_repository *repo;

@end

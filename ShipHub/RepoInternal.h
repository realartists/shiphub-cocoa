//
//  RepoInternal.h
//  ShipHub
//
//  Created by James Howard on 12/6/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "Repo.h"

@interface Repo (Internal)

@property (readwrite) NSString *fullName;
@property (readwrite) NSString *name;
@property (readwrite) NSString *issueTemplate;
@property (readwrite) NSString *pullRequestTemplate;
@property (readwrite, getter=isPrivate) BOOL private;
@property (readwrite) BOOL hasIssues;
@property (readwrite, getter=isHidden) BOOL hidden;
@property (readwrite, getter=isRestricted) BOOL restricted; // if restricted by billing mode

@property (readwrite) NSString *repoDescription;

@property (readwrite) Account *owner;

@property (readwrite) BOOL canPush; // if the current user can push to the repo

@end

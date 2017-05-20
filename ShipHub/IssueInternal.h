//
//  IssueInternal.h
//  ShipHub
//
//  Created by James Howard on 5/19/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "Issue.h"

@interface Issue (Internal)

@property (readwrite) NSArray<CommitStatus *> *commitStatuses;
@property (readwrite) NSArray<CommitComment *> *commitComments;

@end

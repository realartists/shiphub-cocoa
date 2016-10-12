//
//  PRViewController.h
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PullRequest.h"
#import "Issue.h"

@interface PRViewController : NSViewController

- (void)loadForIssue:(Issue *)issue;

@property (nonatomic, strong) PullRequest *pr;

- (void)scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier;

@end

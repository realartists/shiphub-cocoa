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
#import "PRNavigationActionResponder.h"

@interface PRViewController : NSViewController <PRNavigationActionResponder>

- (void)loadForIssue:(Issue *)issue;

@property (nonatomic, strong) PullRequest *pr;

- (void)scrollToLineInfo:(NSDictionary *)lineInfo;// @{ @"type": @"line", @"line": @(123), @"left": @(YES), @"path": @"...", @"sha": @"..." }

@property (readonly) NSToolbar *toolbar; // toolbar for the window we're in

@property (readonly, getter=isInReview) BOOL inReview;

- (IBAction)merge:(id)sender;

- (IBAction)showOmniSearch:(id)sender;

@end

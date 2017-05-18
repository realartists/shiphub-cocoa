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

- (void)scrollToLineInfo:(NSDictionary *)lineInfo;// @{ @"type": @"line", @"line": @(123), @"left": @(YES), @"path": @"...", @"sha": @"..." }

@property (readonly) NSToolbar *toolbar; // toolbar for the window we're in

@property (readonly, getter=isInReview) BOOL inReview;

- (IBAction)nextFile:(id)sender;
- (IBAction)previousFile:(id)sender;

- (IBAction)nextThing:(id)sender;
- (IBAction)previousThing:(id)sender;

- (IBAction)nextChange:(id)sender;
- (IBAction)previousChange:(id)sender;

- (IBAction)nextComment:(id)sender;
- (IBAction)previousComment:(id)sender;

- (IBAction)merge:(id)sender;

@end

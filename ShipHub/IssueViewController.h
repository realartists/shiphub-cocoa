//
//  IssueViewController.h
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IssueWebController.h"

@class Issue;

@interface IssueViewController : IssueWebController

@property (nonatomic, getter=isColumnBrowser) BOOL columnBrowser;

@property (nonatomic) Issue *issue;

- (void)setIssue:(Issue *)issue scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier;

- (void)scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier;

- (void)noteCheckedForIssueUpdates;
- (void)checkForIssueUpdates;

- (void)configureNewIssue;

@property (nonatomic, readonly) BOOL needsSave;

- (void)saveWithCompletion:(void (^)(NSError *err))completion;
- (IBAction)saveDocument:(id)sender;

@end

extern NSString *const IssueViewControllerNeedsSaveDidChangeNotification;
extern NSString *const IssueViewControllerNeedsSaveKey;

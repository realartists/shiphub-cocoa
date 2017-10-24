//
//  IssueDocumentController.h
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Issue;
@class IssueDocument;
@class PRDocument;

@interface IssueDocumentController : NSDocumentController

- (void)openIssueWithIdentifier:(id)issueIdentifier;
- (void)openIssueWithIdentifier:(id)issueIdentifier waitForIt:(BOOL)waitForIt;
// commentIdentifier can nil, an int64 comment identifier, or a BOOL @YES. In the BOOL @YES case, we'll look up the latest notification and grab the comment identifier from that.
- (void)openIssueWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier completion:(void (^)(IssueDocument *doc))completion;
- (void)openIssuesWithIdentifiers:(NSArray *)issueIdentifiers;

- (void)newDocumentWithURL:(NSURL *)URL;
- (void)newDocumentWithIssueTemplate:(Issue *)issueTemplate;
- (void)openDiffWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally scrollInfo:(NSDictionary *)scrollInfo completion:(void (^)(PRDocument *doc))completion;

- (IBAction)newPullRequest:(id)sender;

@end

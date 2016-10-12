//
//  IssueDocumentController.h
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class IssueDocument;
@class PRDocument;

@interface IssueDocumentController : NSDocumentController

- (void)openIssueWithIdentifier:(id)issueIdentifier;
- (void)openIssueWithIdentifier:(id)issueIdentifier waitForIt:(BOOL)waitForIt;
- (void)openIssueWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier completion:(void (^)(IssueDocument *doc))completion;
- (void)openIssuesWithIdentifiers:(NSArray *)issueIdentifiers;

- (void)openDiffWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier completion:(void (^)(PRDocument *doc))completion;


@end

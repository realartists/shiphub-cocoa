//
//  IssueDocumentController.h
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IssueDocumentController : NSDocumentController

- (void)openIssueWithIdentifier:(id)issueIdentifier;
- (void)openIssuesWithIdentifiers:(NSArray *)issueIdentifiers;

@end

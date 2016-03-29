//
//  IssueDocumentController.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueDocumentController.h"

#import "DataStore.h"
#import "Issue.h"
#import "IssueDocument.h"
#import "IssueIdentifier.h"
#import "IssueViewController.h"

@implementation IssueDocumentController

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (IBAction)newDocument:(id)sender {
    if ([[DataStore activeStore] isValid]) {
        [super newDocument:sender];
    }
}

- (void)openIssueWithIdentifier:(id)issueIdentifier {
    for (IssueDocument *doc in [self documents]) {
        if ([[doc.issueViewController.issue fullIdentifier] isEqual:issueIdentifier]) {
            [doc showWindows];
            return;
        }
    }
    
    [[DataStore activeStore] loadFullIssue:issueIdentifier completion:^(Issue *issue, NSError *error) {
        if (issue) {
            IssueDocument *doc = [self openUntitledDocumentAndDisplay:YES error:NULL];
            doc.issueViewController.issue = issue;
            [[DataStore activeStore] checkForIssueUpdates:issueIdentifier];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[issueIdentifier issueGitHubURL]];
        }
    }];
}

- (void)openIssuesWithIdentifiers:(NSArray *)issueIdentifiers {
    for (id identifier in issueIdentifiers) {
        [self openIssueWithIdentifier:identifier];
    }
}

@end

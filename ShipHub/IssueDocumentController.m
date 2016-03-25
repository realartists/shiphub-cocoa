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
    [[DataStore activeStore] issuesMatchingPredicate:[NSPredicate predicateWithFormat:@"fullIdentifier = %@", issueIdentifier] completion:^(NSArray<Issue *> *issues, NSError *error) {
        
        if (issues.count == 1) {
            IssueDocument *doc = [self openUntitledDocumentAndDisplay:YES error:NULL];
            doc.issueViewController.issue = [issues firstObject];
        } else {
            // cannot find, open it on github
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

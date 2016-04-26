//
//  IssueDocumentController.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueDocumentController.h"

#import "DataStore.h"
#import "Error.h"
#import "Issue.h"
#import "IssueDocument.h"
#import "IssueIdentifier.h"
#import "IssueViewController.h"

@interface IssueDocumentController () {
    NSMutableArray *_toRestore;
}

@end

@implementation IssueDocumentController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
}

- (IBAction)newDocument:(id)sender {
    if ([[DataStore activeStore] isValid]) {
        IssueDocument *doc = [self openUntitledDocumentAndDisplay:YES error:NULL];
        [doc.issueViewController configureNewIssue];
    }
}

- (void)openIssueWithIdentifier:(id)issueIdentifier {
    [self openIssueWithIdentifier:issueIdentifier canOpenExternally:YES completion:nil];
}

- (void)openIssueWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally completion:(void (^)(IssueDocument *doc))completion {
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
            if (completion) {
                completion(doc);
            }
        } else {
            if (canOpenExternally) {
                [[NSWorkspace sharedWorkspace] openURL:[issueIdentifier issueGitHubURL]];
            }
            if (completion) {
                completion(nil);
            }
        }
    }];
}

- (void)openIssuesWithIdentifiers:(NSArray *)issueIdentifiers {
    for (id identifier in issueIdentifiers) {
        [self openIssueWithIdentifier:identifier];
    }
}

- (void)didFinishLaunching:(NSNotification *)note {
    if (![[DataStore activeStore] isValid])
        return;
    
    for (id issueIdentifier in _toRestore) {
        [self openIssueWithIdentifier:issueIdentifier canOpenExternally:NO completion:nil];
    }
}

+ (void)restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    [[IssueDocumentController sharedDocumentController] _restoreWindowWithIdentifier:identifier state:state completionHandler:completionHandler];
}

- (void)_restoreWindowWithIdentifier:(NSString *)identifier state:(NSCoder *)state completionHandler:(void (^)(NSWindow *, NSError *))completionHandler
{
    if (!_toRestore) {
        _toRestore = [NSMutableArray new];
    }
    
    NSString *issueIdentifier = [state decodeObjectOfClass:[NSString class] forKey:@"IssueIdentifier"];
    
    if (issueIdentifier) {
        [_toRestore addObject:issueIdentifier];
    }
    
    completionHandler(nil, nil);
}


@end

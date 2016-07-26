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
#import "AppDelegate.h"
#import "OverviewController.h"

@interface IssueDocumentController () {
    NSMutableArray *_toRestore;
}

@property IBOutlet NSMenu *recentItemsMenu;

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
            [[DataStore activeStore] markIssueAsRead:issueIdentifier];
            [self noteNewRecentDocument:doc];
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
    
    [self updateRecents];
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

- (void)noteNewRecentDocument:(IssueDocument *)document {
    id identifier = document.issueViewController.issue.fullIdentifier;
    if (!identifier) return;
    
    NSString *title = document.issueViewController.issue.title ?: @"";
    
    NSMutableArray *recents = [[[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentDocuments"] mutableCopy];
    if (!recents) {
        recents = [NSMutableArray array];
    }
    
    NSUInteger i = 0, itemIdx = NSNotFound;
    for (NSDictionary *entry in recents) {
        if ([entry[@"identifier"] isEqual:identifier]) {
            itemIdx = i;
            break;
        }
        i++;
    }
    
    if (itemIdx != NSNotFound) {
        [recents removeObjectAtIndex:itemIdx];
    }
    
    [recents addObject:@{@"identifier":identifier, @"title":title}]; // recents is reverse sorted
    
    NSUInteger maxDocs = [self myMaximumRecentDocumentCount];
    if (recents.count > maxDocs) {
        [recents removeObjectsInRange:NSMakeRange(0, recents.count - maxDocs)];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:recents forKey:@"RecentDocuments"];
    
    [self updateRecents];
}

- (NSUInteger)myMaximumRecentDocumentCount {
    return [super maximumRecentDocumentCount];
}

- (NSUInteger)maximumRecentDocumentCount {
    return 0; // I managed recents myself, I don't want Cocoa to do it for me.
}

- (IBAction)openRecent:(id)sender {
    id identifier = [sender representedObject];
    [self openIssueWithIdentifier:identifier];
}

- (void)updateRecents {
    NSArray *recents = [[NSUserDefaults standardUserDefaults] objectForKey:@"RecentDocuments"];
    
    // Remove old items
    NSMenuItem *item = nil;
    while ((item = [_recentItemsMenu itemAtIndex:0]).action == @selector(openRecent:)) {
        [_recentItemsMenu removeItemAtIndex:0];
    }
    
    if (recents.count > 0) {
        [_recentItemsMenu insertItem:[NSMenuItem separatorItem] atIndex:0];
    }
    
    for (NSDictionary *recent in recents) {
        NSString *title = [NSString localizedStringWithFormat:NSLocalizedString(@"#%@ %@", @"Open Recent menu item title format string"), recent[@"identifier"], recent[@"title"]];
        item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openRecent:) keyEquivalent:@""];
        item.representedObject = recent[@"identifier"];
        [_recentItemsMenu insertItem:item atIndex:0];
    }
    
}

- (IBAction)clearRecentDocuments:(id)sender {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"RecentDocuments"];
    [self updateRecents];
}

- (Issue *)keyOrSelectedProblem {
    IssueDocument *doc = [self currentDocument];
    if (doc) {
        return doc.issueViewController.issue;
    } else {
        OverviewController *activeOverview = [[AppDelegate sharedDelegate] activeOverviewController];
        NSArray *snaps = [activeOverview selectedIssues];
        if ([snaps count] != 1) {
            return nil;
        } else {
            return snaps[0];
        }
    }
}

- (IBAction)cloneIssue:(id)sender {
    Issue *src = [self keyOrSelectedProblem];
    
    Issue *clone = [src clone];
    IssueDocument *newDoc = [self openUntitledDocumentAndDisplay:YES error:NULL];
    newDoc.issueViewController.issue = clone;
}

@end

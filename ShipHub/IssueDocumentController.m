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
#import "Extras.h"
#import "Issue.h"
#import "PullRequest.h"
#import "IssueWaiter.h"
#import "IssueDocument.h"
#import "PRDocument.h"
#import "IssueIdentifier.h"
#import "IssueViewController.h"
#import "AppDelegate.h"
#import "OverviewController.h"
#import "MetadataStore.h"
#import "Account.h"
#import "Milestone.h"
#import "Repo.h"
#import "Label.h"
#import "PRCreateController.h"

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

// Work around rdar://28899384 <New windows can be opened in wrong tab group after newWindowForTab:>
- (BOOL)respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(newWindowForTab:)) {
        return NO;
    }
    return [super respondsToSelector:aSelector];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(openDocument:)) {
        return NO;
    } else if (menuItem.action == @selector(cloneIssue:)) {
        return [self keyOrSelectedProblem] != nil;
    }
    return [super validateMenuItem:menuItem];
}

- (IBAction)openDocument:(id)sender {
    // nop
}

- (NSString *)defaultType {
    return @"issue";
}

- (NSString *)displayNameForType:(NSString *)typeName {
    if ([typeName isEqualToString:@"issue"]) {
        return NSLocalizedString(@"Issue", nil);
    } else if ([typeName isEqualToString:@"diff"]) {
        return NSLocalizedString(@"Diff", nil);
    } else {
        NSAssert(NO, nil);
        return nil;
    }
}

- (NSArray<NSString *> *)documentClassNames {
    return @[@"IssueDocument", @"DiffDocument"];
}

- (Class)documentClassForType:(NSString *)typeName {
    if ([typeName isEqualToString:@"issue"]) {
        return [IssueDocument class];
    } else if ([typeName isEqualToString:@"diff"]) {
        return [PRDocument class];
    } else {
        NSAssert(NO, nil);
        return nil;
    }
}

- (NSArray<IssueDocument *> *)issueDocuments {
    return [[self documents] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject class] == [IssueDocument class];
    }]];
}

- (NSArray<PRDocument *> *)diffDocuments {
    return [[self documents] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        return [evaluatedObject class] == [PRDocument class];
    }]];
}

- (IBAction)newDocument:(id)sender {
    if ([[DataStore activeStore] isValid]) {
        OverviewController *activeOverview = [[AppDelegate sharedDelegate] activeOverviewController];
        NSURL *templateURL = [activeOverview issueTemplateURLForSidebarSelection];
        if (templateURL) {
            [self newDocumentWithURL:templateURL];
        } else {
            IssueDocument *doc = [self openUntitledDocumentAndDisplay:YES error:NULL];
            [doc.issueViewController configureNewIssue];
        }
    }
}

- (void)openIssueWithIdentifier:(id)issueIdentifier {
    [self openIssueWithIdentifier:issueIdentifier canOpenExternally:YES completion:nil];
}

- (void)openIssueWithIdentifier:(id)issueIdentifier waitForIt:(BOOL)waitForIt {
    if (!waitForIt) {
        [self openIssueWithIdentifier:issueIdentifier canOpenExternally:YES completion:nil];
    } else {
        [self openIssueWithIdentifier:issueIdentifier canOpenExternally:NO completion:^(IssueDocument *doc) {
            if (!doc) {
                [[IssueWaiter waiterForIssueIdentifier:issueIdentifier] waitForIssue:^(Issue *issue) {
                    [self openIssueWithIdentifier:issueIdentifier canOpenExternally:YES completion:nil];
                }];
            }
        }];
    }
}

- (void)openIssueWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally completion:(void (^)(IssueDocument *doc))completion {
    [self openIssueWithIdentifier:issueIdentifier canOpenExternally:canOpenExternally scrollToCommentWithIdentifier:nil completion:completion];
}


- (void)openIssueWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier completion:(void (^)(IssueDocument *doc))completion {
    [self openIssueWithIdentifier:issueIdentifier display:YES canOpenExternally:canOpenExternally scrollToCommentWithIdentifier:commentIdentifier completion:completion];
}

- (void)openIssueWithIdentifier:(id)issueIdentifier display:(BOOL)display canOpenExternally:(BOOL)canOpenExternally scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier completion:(void (^)(IssueDocument *doc))completion {
    for (IssueDocument *doc in [self issueDocuments]) {
        if ([[doc.issueViewController.issue fullIdentifier] isEqual:issueIdentifier]) {
            if (display) [doc showWindows];
            if (commentIdentifier) {
                [doc.issueViewController scrollToCommentWithIdentifier:commentIdentifier];
            }
            if (completion) {
                completion(doc);
            }
            return;
        }
    }
    
    [[DataStore activeStore] loadFullIssue:issueIdentifier completion:^(Issue *issue, NSError *error) {
        if (issue) {
            IssueDocument *doc = [self makeUntitledDocumentOfType:@"issue" error:NULL];
            [self addDocument:doc];
            [doc makeWindowControllers];
            if (display) {
                [doc showWindows];
            }
            [doc.issueViewController setIssue:issue scrollToCommentWithIdentifier:commentIdentifier];
            [doc.issueViewController checkForIssueUpdates];
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

- (void)openDiffWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally scrollToCommentWithIdentifier:(NSNumber *)commentIdentifier completion:(void (^)(PRDocument *doc))completion
{
    for (PRDocument *doc in [self diffDocuments]) {
        if ([[doc.prViewController.pr.issue fullIdentifier] isEqual:issueIdentifier]) {
            [doc showWindows];
            if (commentIdentifier) {
                [doc.prViewController scrollToCommentWithIdentifier:commentIdentifier];
            }
            return;
        }
    }
    
    [[DataStore activeStore] loadFullIssue:issueIdentifier completion:^(Issue *issue, NSError *error) {
        if (issue) {
            PRDocument *doc = [self makeUntitledDocumentOfType:@"diff" error:NULL];
            [self addDocument:doc];
            [doc makeWindowControllers];
            [doc showWindows];
            [doc.prViewController loadForIssue:issue];
            [doc.prViewController scrollToCommentWithIdentifier:commentIdentifier];
            
            if (completion) {
                completion(doc);
            }
        } else {
            if (canOpenExternally) {
                [[NSWorkspace sharedWorkspace] openURL:[PullRequest gitHubFilesURLForIssueIdentifier:issueIdentifier]];
            }
            if (completion) {
                completion(nil);
            }
        }
    }];
}

- (void)openIssuesWithIdentifiers:(NSArray *)issueIdentifiers {
    if ([issueIdentifiers count] > 10) {
        issueIdentifiers = [issueIdentifiers subarrayWithRange:NSMakeRange(0, 10)];
    }
    SEL addTabbedSEL = NSSelectorFromString(@"addTabbedWindow:ordered:");
    if ([NSWindow instancesRespondToSelector:addTabbedSEL]) {
        // realartists/shiphub-cocoa#270 Opening multiple issues at once should open them in tabs on Sierra
        __block NSWindow *groupWindow = nil;
        __block NSInteger i = 0;
        __block NSInteger count = issueIdentifiers.count;
        for (id identifier in issueIdentifiers) {
            [self openIssueWithIdentifier:identifier display:NO canOpenExternally:YES scrollToCommentWithIdentifier:nil completion:^(IssueDocument *doc) {
                i++;
                NSWindow *window = [[doc.windowControllers firstObject] window];
                if (window) {
                    if (!groupWindow) {
                        groupWindow = window;
                    } else {
                        NSMethodSignature *sig = [groupWindow methodSignatureForSelector:addTabbedSEL];
                        NSInvocation *ivk = [NSInvocation invocationWithMethodSignature:sig];
                        ivk.target = groupWindow;
                        ivk.selector = addTabbedSEL;
                        id arg2 = window;
                        NSWindowOrderingMode arg3 = NSWindowBelow;
                        [ivk setArgument:&arg2 atIndex:2];
                        [ivk setArgument:&arg3 atIndex:3];
                        [ivk invoke];
                    }
                }
                if (i == count) {
                    [groupWindow makeKeyAndOrderFront:nil];
                }
            }];
        }
    } else {
        for (id identifier in issueIdentifiers) {
            [self openIssueWithIdentifier:identifier];
        }
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

- (void)noteNewRecentDocument:(NSDocument *)document {
    if (![document isKindOfClass:[IssueDocument class]]) return; // FIXME: Recents for diffs?
    
    IssueDocument *idoc = (id)document;
    id identifier = idoc.issueViewController.issue.fullIdentifier;
    if (!identifier) return;
    
    NSString *title = idoc.issueViewController.issue.title ?: @"";
    
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
    id doc = [self currentDocument];
    if ([doc isKindOfClass:[IssueDocument class]]) {
        return [[doc issueViewController] issue];
    } else if ([doc isKindOfClass:[PRDocument class]]) {
        return [[[doc prViewController] pr] issue];
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

- (void)newDocumentWithIssueTemplate:(Issue *)template {
    IssueDocument *newDoc = [self openUntitledDocumentAndDisplay:YES error:NULL];
    newDoc.issueViewController.issue = template;
}

- (IBAction)cloneIssue:(id)sender {
    Issue *src = [self keyOrSelectedProblem];
    
    Issue *clone = [src clone];
    if (clone) {
        [self newDocumentWithIssueTemplate:clone];
    }
}

- (void)newDocumentWithURL:(NSURL *)URL {
    // ship+github://newissue/realartists/shiphub-cocoa?title=...&assignees
    
    NSURLComponents *comps = [[NSURLComponents alloc] initWithURL:URL resolvingAgainstBaseURL:YES];
    NSDictionary *args = [comps queryItemsDictionary];
    
    MetadataStore *m = [[DataStore activeStore] metadataStore];
    
    Repo *repo = nil;
    NSString *title = nil;
    NSArray<Account *> *assignees = @[];
    NSArray<Label *> *labels = @[];
    Milestone *milestone = nil;
    NSString *body = nil;
    
    NSString *path = [comps.path substringFromIndex:1];
    repo = [m repoWithFullName:path];
    
    title = args[@"title"];
    
    if (args[@"body"]) {
        body = args[@"body"];
    } else if (repo) {
        body = repo.issueTemplate;
    }
    
    if (repo && args[@"milestone"]) {
        milestone = [m milestoneWithTitle:args[@"milestone"] inRepo:repo];
    }
    
    if (repo && args[@"labels"]) {
        NSMutableArray *ll = [NSMutableArray new];
        NSArray *ls = [args[@"labels"] componentsSeparatedByString:@","];
        NSDictionary *vals = [NSDictionary lookupWithObjects:[m labelsForRepo:repo] keyPath:@"name"];
        for (NSString *ln in ls) {
            Label *l = vals[ln];
            if (l) [ll addObject:l];
        }
        labels = ll;
    }
    
    if (repo && (args[@"assignees"] || args[@"assignee"])) {
        NSMutableArray *aa = [NSMutableArray new];
        NSArray *as = nil;
        if (args[@"assignees"]) {
            as = [args[@"assignees"] componentsSeparatedByString:@","];
        } else {
            as = @[args[@"assignee"]];
        }
        NSDictionary *vals = [NSDictionary lookupWithObjects:[m assigneesForRepo:repo] keyPath:@"login"];
        for (NSString *al in as) {
            Account *a = vals[al];
            if (a) [aa addObject:a];
        }
        assignees = aa;
    }
    
    Issue *i = [[Issue alloc] initWithTitle:title repo:repo milestone:milestone assignees:assignees labels:labels body:body];
    [self newDocumentWithIssueTemplate:i];
}

- (IBAction)newPullRequest:(id)sender {
    PRCreateController *prc = [PRCreateController new];
    [prc showWindow:sender]; // prc manages its own lifetime.
}

@end

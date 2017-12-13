//
//  PRDocumentController.m
//  ShipHub
//
//  Created by James Howard on 8/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEDocumentController.h"

#import "Issue.h"
#import "RMEDataStore.h"
#import "RMEOpenController.h"
#import "PRDocument.h"
#import "PRViewController.h"

@interface RMEDocumentController () {
    NSMutableArray *_toRestore;
    RMEOpenController *_openController;
}

@property IBOutlet NSMenu *recentItemsMenu;

@end

@implementation RMEDocumentController

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishLaunching:) name:NSApplicationDidFinishLaunchingNotification object:nil];
}

- (void)openDiffWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally scrollInfo:(NSDictionary *)scrollInfo completion:(void (^)(PRDocument *doc))completion {
    for (PRDocument *doc in [self documents]) {
        if ([[doc.prViewController.pr.issue fullIdentifier] isEqual:issueIdentifier]) {
            [doc showWindows];
            if (scrollInfo) {
                [doc.prViewController scrollToLineInfo:scrollInfo];
            }
            return;
        }
    }
    
    [[RMEDataStore activeStore] loadFullIssue:issueIdentifier completion:^(Issue *issue, NSError *error) {
        if (issue) {
            PRDocument *doc = [self makeUntitledDocumentOfType:@"diff" error:NULL];
            [self addDocument:doc];
            [doc makeWindowControllers];
            [doc showWindows];
            [doc.prViewController loadForIssue:issue];
            if (scrollInfo) [doc.prViewController scrollToLineInfo:scrollInfo];
            
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

- (Class)documentClassForType:(NSString *)typeName {
    return [PRDocument class];
}

- (IBAction)openDocument:(id)sender {
    if (!_openController) {
        _openController = [RMEOpenController new];
    }
    [_openController showWindow:sender];
}

- (IBAction)newDocument:(id)sender {
    // nop
}

- (IBAction)newPullRequest:(id)sender { }

- (void)didFinishLaunching:(NSNotification *)note {
#if 0
    if (![[DataStore activeStore] isValid])
        return;
    
    [self updateRecents];
    for (id issueIdentifier in _toRestore) {
        [self openIssueWithIdentifier:issueIdentifier canOpenExternally:NO completion:nil];
    }
#endif
}


@end

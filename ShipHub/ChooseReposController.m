//
//  ChooseReposController.m
//  ShipHub
//
//  Created by James Howard on 2/26/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "ChooseReposController.h"

@class RepoNode;

@interface RepoGroupNode : NSObject {
    NSMutableArray *_children;
}

@property NSInteger state;

- (void)rebuildState;

@property NSString *name;

@property (nonatomic, readonly) NSArray *repos;

- (void)addRepo:(RepoNode *)name;
- (void)addGlobalFollowChildWithState:(BOOL)checked;

@end

@interface RepoNode : NSObject

@property BOOL checked;
@property NSString *name;
@property NSString *fullName;

@property (weak) RepoGroupNode *parent;

@end

@interface ChooseRepoCell : NSTableCellView

@property IBOutlet NSButton *check;
@property IBOutlet NSTextField *privateField;

@end

@interface ChooseReposController ()

@property IBOutlet NSOutlineView *outline;
@property IBOutlet NSButton *doneButton;

@property NSArray *groups;
@property BOOL globalFollow; // whether or not to auto-follow in Ship any new organizations joined

@end

@implementation ChooseReposController

- (id)init {
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Choose Repos", nil);
    }
    return self;
}

- (NSString *)nibName {
    return @"ChooseReposController";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)refresh:(id)sender {
    
}

- (IBAction)moreInfo:(id)sender {
    
}

- (IBAction)done:(id)sender {
    
}

- (void)updateWithRepos:(NSArray *)repos {
    // walk the tree and compute the current checked state for each repo
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    
    for (RepoGroupNode *group in _groups) {
        for (RepoNode *repo in group.repos) {
            state[repo.fullName] = @(repo.checked);
        }
    }
    
    // Now build a new tree given the list of repos and the previous state
    repos = [repos sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"full_name" ascending:YES]]];
    
    NSMutableArray *groups = [NSMutableArray new];
    RepoGroupNode *group = nil;
    for (NSDictionary *repo in repos) {
        NSString *fullName = repo[@"full_name"];
        NSArray *comps = [fullName componentsSeparatedByString:@"/"];
        if (comps.count == 2) {
            NSString *owner = comps[0];
            NSString *name = comps[1];
            
            if (!group || ![group.name isEqualToString:owner]) {
                group = [RepoGroupNode new];
                group.name = owner;
                NSNumber *globalState = state[[NSString stringWithFormat:@"%@/_new_", owner]];
                [group addGlobalFollowChildWithState:globalState == nil || [globalState boolValue]];
                [groups addObject:group];
            }
            
            RepoNode *node = [RepoNode new];
            node.fullName = fullName;
            node.name = name;
            NSNumber *nodeState = state[fullName];
            node.checked = nodeState == nil || [nodeState boolValue];
            [group addRepo:node];
        }
    }
    
    for (group in groups) {
        [group rebuildState];
    }
    
    _groups = groups;
    [_outline reloadData];
}

- (IBAction)checkChanged:(id)sender {
    
}

@end

@implementation ChooseRepoCell

@end

@implementation RepoGroupNode

@end

@implementation RepoNode

@end

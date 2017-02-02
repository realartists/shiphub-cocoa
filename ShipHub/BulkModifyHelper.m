//
//  BulkModifyHelper.m
//  ShipHub
//
//  Created by James Howard on 7/26/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "BulkModifyHelper.h"

#import "Error.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Issue.h"
#import "Milestone.h"
#import "Repo.h"
#import "User.h"

#import "ProgressSheet.h"
#import "BulkModifyController.h"

#import "MilestoneModifyController.h"
#import "LabelModifyController.h"
#import "AssigneeModifyController.h"
#import "StateModifyController.h"

@interface BulkModifyHelper () <BulkModifyDelegate>

@property NSWindow *bulkParentWindow;
@property NSWindow *editSheet;
@property BulkModifyController *currentOperation;
@property ProgressSheet *progressSheet;
@property BOOL showingError;

@end

@implementation BulkModifyHelper

+ (instancetype)sharedHelper {
    static BulkModifyHelper *sharedHelper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHelper = [BulkModifyHelper new];
    });
    return sharedHelper;
}

// Used for drag and drop
- (void)moveIssues:(NSArray<NSString *> *)issueIdentifiers toMilestone:(NSString *)milestoneTitle window:(NSWindow *)window completion:(void (^)(NSError *error))completion
{
    DataStore *store = [DataStore activeStore];
    MetadataStore *meta = [store metadataStore];
    
    NSMutableArray *errors = [NSMutableArray array];
    
    
    [store issuesMatchingPredicate:[store predicateForIssueIdentifiers:issueIdentifiers] completion:^(NSArray<Issue *> *issues, NSError *error) {
    
        dispatch_group_t group = dispatch_group_create();
        for (Issue *issue in issues) {
            NSString *issueMilestoneTitle = issue.milestone.title;
            if (!issueMilestoneTitle || ![issueMilestoneTitle isEqualToString:milestoneTitle])
            {
                Milestone *next = [meta milestoneWithTitle:milestoneTitle inRepo:issue.repository];
                if (next) {
                    dispatch_group_enter(group);
                    [store patchIssue:@{ @"milestone" : next.number } issueIdentifier:issue.fullIdentifier completion:^(Issue *i, NSError *e) {
                        if (e) {
                            [errors addObject:e];
                        }
                        dispatch_group_leave(group);
                    }];
                } else {
                    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The milestone %@ does not exist for the repo %@", nil), milestoneTitle, issue.repository.fullName];
                    NSError *missingMilestone = [NSError shipErrorWithCode:ShipErrorCodeProblemSaveOtherError localizedMessage:message];
                    [errors addObject:missingMilestone];
                }
            }
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            if (completion) {
                completion([errors firstObject]);
            }
            if ([errors count]) {
                NSAlert *alert = [NSAlert new];
                alert.messageText = NSLocalizedString(@"One or more issues could not be modified", nil);
                alert.informativeText = [[errors firstObject] localizedDescription];
                [alert beginSheetModalForWindow:window completionHandler:nil];
            }
        });
        
    }];
}

- (void)beginEditOperation:(BulkModifyController *)bulkController inWindow:(NSWindow *)window {
    if (_currentOperation) {
        if (window != _bulkParentWindow) {
            NSAlert *err = [NSAlert new];
            err.messageText = NSLocalizedString(@"Cannot begin bulk modify", nil);
            err.informativeText = NSLocalizedString(@"Another bulk modify is already in progress. Please wait for that to finish before beginning a second one.", nil);
            [err runModal];
        } else {
            NSAssert(NO, @"Can't run two bulk modify operations at once in one parent window");
        }
        return;
    }
    
    NSView *bulkView = bulkController.view;
    NSWindow *sheetWindow = [[NSWindow alloc] initWithContentRect:bulkView.bounds styleMask:0 backing:NSBackingStoreBuffered defer:YES];
    sheetWindow.hasShadow = YES;
    sheetWindow.contentViewController = bulkController;
    
    _bulkParentWindow = window;
    _editSheet = sheetWindow;
    _currentOperation = bulkController;
    _currentOperation.delegate = self;
    
    [_bulkParentWindow beginSheet:_editSheet completionHandler:nil];
}

- (void)bulkModifyDidBegin:(BulkModifyController *)controller {
    [_bulkParentWindow endSheet:_editSheet];
    _progressSheet = [ProgressSheet new];
    _progressSheet.message = NSLocalizedString(@"Updating issues", nil);
    [_progressSheet beginSheetInWindow:_bulkParentWindow];
}

- (void)bulkModifyDidEnd:(BulkModifyController *)controller error:(NSError *)error {
    if (_progressSheet) {
        [_progressSheet endSheet];
    }
    
    dispatch_block_t cleanup = ^{
        _bulkParentWindow = nil;
        _editSheet = nil;
        _currentOperation = nil;
        _progressSheet = nil;
        _showingError = NO;
    };
    
    if (error) {
        NSAlert *err = [NSAlert new];
        err.messageText = NSLocalizedString(@"One or more issues could not be modified", nil);
        err.informativeText = [error localizedDescription];
        [err beginSheetModalForWindow:_bulkParentWindow completionHandler:^(NSModalResponse returnCode) {
            cleanup();
        }];
    } else {
        cleanup();
    }
}

- (void)bulkModifyDidCancel:(BulkModifyController *)controller {
    [_bulkParentWindow endSheet:_editSheet];
    _bulkParentWindow = nil;
    _editSheet = nil;
    _currentOperation = nil;
    _progressSheet = nil;
    _showingError = NO;
}

- (void)editMilestone:(NSArray<Issue *> *)issues window:(NSWindow *)window {
    MilestoneModifyController *bulk = [[MilestoneModifyController alloc] initWithIssues:issues];
    [self beginEditOperation:bulk inWindow:window];
}

- (void)editLabels:(NSArray<Issue *> *)issues window:(NSWindow *)window {
    LabelModifyController *bulk = [[LabelModifyController alloc] initWithIssues:issues];
    [self beginEditOperation:bulk inWindow:window];
}

- (void)editAssignees:(NSArray<Issue *> *)issues window:(NSWindow *)window {
    AssigneeModifyController *bulk = [[AssigneeModifyController alloc] initWithIssues:issues];
    [self beginEditOperation:bulk inWindow:window];
}

- (void)editState:(NSArray<Issue *> *)issues window:(NSWindow *)window {
    StateModifyController *bulk = [[StateModifyController alloc] initWithIssues:issues];
    [self beginEditOperation:bulk inWindow:window];
}

@end

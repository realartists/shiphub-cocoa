//
//  PRPostMergeController.m
//  ShipHub
//
//  Created by James Howard on 5/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRPostMergeController.h"

#import "Issue.h"
#import "PRAdapter.h"
#import "Extras.h"

@interface PRPostMergeController ()

@property IBOutlet NSTextField *infoLabel;
@property IBOutlet NSButton *deleteButton;

@end

@implementation PRPostMergeController

- (NSString *)windowNibName { return @"PRPostMergeController"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    _deleteButton.state = NSOffState;
}

- (void)setIssue:(Issue *)issue {
    [self window];
    
    _issue = issue;
    
    NSDictionary *baseRepo, *headRepo;
    baseRepo = headRepo = nil;
    
    if ([issue.base[@"repo"] isKindOfClass:[NSDictionary class]]) {
        baseRepo = issue.base[@"repo"];
    }
    
    if ([issue.head[@"repo"] isKindOfClass:[NSDictionary class]]) {
        headRepo = issue.head[@"repo"];
    }
    
    if (baseRepo[@"fullName"] != nil
        && [NSObject object:baseRepo[@"fullName"] isEqual:headRepo[@"fullName"]]
        && ![headRepo[@"defaultBranch"] isEqualToString:issue.head[@"ref"]])
    {
        _infoLabel.hidden = NO;
        _deleteButton.state = NSOffState;
        _deleteButton.hidden = NO;
        
        NSString *infoStr = [NSString stringWithFormat:NSLocalizedString(@"The \"%@\" branch can safely be deleted.", nil), issue.head[@"ref"]];
        
        _infoLabel.stringValue = infoStr;
    } else {
        _infoLabel.hidden = YES;
        _deleteButton.state = NSOffState;
        _deleteButton.hidden = YES;
    }
}

- (IBAction)ok:(id)sender {
    if (_deleteButton.state == NSOnState) {
        id<PRAdapter> adapter = CreatePRAdapter(_issue);
        [adapter deletePullRequestBranchWithCompletion:nil];
    }
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (void)beginSheetModalForWindow:(NSWindow *)parentWindow completion:(dispatch_block_t)completion
{
    CFRetain((__bridge CFTypeRef)self);
    [parentWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        if (completion) completion();
        CFRelease((__bridge CFTypeRef)self);
    }];
}

@end

//
//  StateModifyController.m
//  ShipHub
//
//  Created by James Howard on 7/27/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "StateModifyController.h"

#import "Extras.h"
#import "Error.h"
#import "DataStore.h"
#import "Issue.h"

@interface StateModifyController ()

@property IBOutlet NSTextField *infoLabel;

@property IBOutlet NSButton *closeButton;
@property IBOutlet NSButton *openButton;
@property IBOutlet NSButton *cancelButton;

@property NSArray<Issue *> *openIssues;
@property NSArray<Issue *> *closedIssues;

@end

@implementation StateModifyController

- (id)initWithIssues:(NSArray<Issue *> *)issues {
    if (self = [super initWithIssues:issues]) {
        _openIssues = [issues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"closed = NO"]];
        _closedIssues = [issues filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"closed = YES"]];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGPoint cancelAltOrigin = _openButton.frame.origin;
    cancelAltOrigin.x += _openButton.frame.size.width - _cancelButton.frame.size.width;
    
    if (_openIssues.count > 0 && _closedIssues.count > 0) {
        // use both buttons
        _infoLabel.stringValue = [NSString localizedStringWithFormat:NSLocalizedString(@"Modifying: Open Issues: %tu, Closed Issues: %tu", nil), _openIssues.count, _closedIssues.count];
        if (_openIssues.count == 1) {
            [_closeButton setTitle:NSLocalizedString(@"Close Issue", nil)];
        }
        if (_closedIssues.count == 1) {
            [_openButton setTitle:NSLocalizedString(@"Reopen Issue", nil)];
        }
    } else if (_openIssues.count > 0) {
        _openButton.hidden = YES;
        _closeButton.keyEquivalent = @"\r";
        if (_openIssues.count == 1) {
            [_closeButton setTitle:NSLocalizedString(@"Close Issue", nil)];
            _infoLabel.stringValue = NSLocalizedString(@"Modifying 1 Open Issue", nil);
        } else {
            _infoLabel.stringValue = [NSString localizedStringWithFormat:NSLocalizedString(@"Modifying %tu Open Issues", nil), _openIssues.count];
        }
        [_cancelButton setFrameOrigin:cancelAltOrigin];
    } else if (_closedIssues.count > 0) {
        _openButton.frame = _closeButton.frame;
        _openButton.keyEquivalent = @"\r";
        _closeButton.hidden = YES;
        if (_closedIssues.count == 1) {
            [_openButton setTitle:NSLocalizedString(@"Reopen Issue", nil)];
            _infoLabel.stringValue = NSLocalizedString(@"Modifying 1 Closed Issue", nil);
        } else {
            _infoLabel.stringValue = [NSString localizedStringWithFormat:NSLocalizedString(@"Modifying %tu Closed Issues", nil), _closedIssues.count];
        }
        [_cancelButton setFrameOrigin:cancelAltOrigin];
    }
}

- (void)updateIssues:(NSArray *)issues state:(NSString *)state {
    [self.delegate bulkModifyDidBegin:self];
    
    DataStore *store = [DataStore activeStore];
    
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray *errors = [NSMutableArray new];
    
    for (Issue *issue in issues) {
        dispatch_group_enter(group);
        [store patchIssue:@{ @"state" : state } issueIdentifier:issue.fullIdentifier completion:^(Issue *i, NSError *error) {
            
            if (error) {
                [errors addObject:error];
            }
            dispatch_group_leave(group);
        }];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self.delegate bulkModifyDidEnd:self error:[errors firstObject]];
    });
}

- (IBAction)closeIssues:(id)sender {
    [self updateIssues:_openIssues state:@"closed"];
}

- (IBAction)openIssues:(id)sender {
    [self updateIssues:_closedIssues state:@"open"];
}

- (IBAction)cancel:(id)sender {
    [self.delegate bulkModifyDidCancel:self];
}

@end

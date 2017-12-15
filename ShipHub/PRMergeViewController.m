//
//  PRMergeViewController.m
//  ShipHub
//
//  Created by James Howard on 3/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRMergeViewController.h"

#import "Extras.h"
#import "Repo.h"
#import "DataStore.h"
#import "MetadataStore.h"

@interface PRMergeViewController () <NSTextFieldDelegate, NSTextViewDelegate>

@property IBOutlet NSTextField *titleField;
@property IBOutlet NSTextView *messageView;
@property IBOutlet NSButton *mergeButton;
@property IBOutlet NSButton *squashButton;
@property IBOutlet NSButton *rebaseButton;

@property BOOL titleEdited;
@property BOOL messageEdited;

@property Repo *repository;

@end

@implementation PRMergeViewController

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _mergeButton.state = NSOnState;
    [_titleField setDelegate:self];
    [_messageView setDelegate:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(metadataDidChange:) name:DataStoreDidUpdateMetadataNotification object:nil];
}

- (void)metadataDidChange:(NSNotification *)note {
    Repo *updatedRepo = [note.userInfo[DataStoreMetadataKey] repoWithIdentifier:_issue.repository.identifier];
    if (updatedRepo) {
        _repository = updatedRepo;
        [self updateTitleAndMessage];
    }
}

- (void)updateTitleAndMessage {
    Issue *i = _issue;
    
    _titleField.enabled = YES;
    _messageView.enabled = YES;
    
    _mergeButton.enabled = _repository.allowMergeCommit;
    _rebaseButton.enabled = _repository.allowRebaseMerge;
    _squashButton.enabled = _repository.allowSquashMerge;
    
    BOOL needsEnableNext = NO;
    NSArray *buttons = @[_mergeButton, _squashButton, _rebaseButton];
    for (NSButton *b in buttons) {
        if (!b.enabled && b.state == NSOnState) {
            b.state = NSOffState;
            needsEnableNext = YES;
        }
    }
    if (needsEnableNext) {
        for (NSButton *b in buttons) {
            if (b.enabled) {
                b.state = NSOnState;
            }
        }
    }
    
    if (_mergeButton.state == NSOnState) {
        if (!_titleEdited) {
            _titleField.stringValue = i != nil ? [NSString stringWithFormat:@"Merge pull request #%@ from %@/%@", i.number, _repository.fullName, i.head[@"ref"]] : @"";
        }
        if (!_messageEdited) {
            _messageView.string = i.title ?: @"";
        }
    } else if (_squashButton.state == NSOnState) {
        if (!_titleEdited) {
            _titleField.stringValue = i != nil ? [NSString stringWithFormat:@"%@ (#%@)", i.title, i.number] : @"";
        }
        if (!_messageEdited) {
            _messageView.string = @"";
        }
    } else /* if (_rebaseButton.state == NSOnState) */ {
        if (!_titleEdited) {
            _titleField.placeholderString = NSLocalizedString(@"Not Applicable", nil);
            _titleField.stringValue = @"";
        }
        _titleField.enabled = NO;
        _messageView.enabled = NO;
    }
}

- (void)controlTextDidChange:(NSNotification *)notification {
    if (notification.object == _titleField) {
        _titleEdited = YES;
    }
}

- (void)textDidChange:(NSNotification *)notification {
    if (notification.object == _messageView) {
        _messageEdited = YES;
    }
}

- (void)setIssue:(Issue *)i {
    [self view];
    if (_issue != i) {
        _issue = i;
        _repository = i.repository;
        _titleEdited = _messageEdited = NO;
        [self updateTitleAndMessage];
    }
}

- (IBAction)radioToggle:(id)sender {
    for (NSButton *b in @[_mergeButton, _squashButton, _rebaseButton]) {
        b.state = sender == b ? NSOnState : NSOffState;
    }
    [self updateTitleAndMessage];
}

- (IBAction)help:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://help.github.com/articles/about-pull-request-merges/"]];
}

- (IBAction)submit:(id)sender {
    PRMergeStrategy strat;
    if (_mergeButton.state == NSOnState) {
        strat = PRMergeStrategyMerge;
    } else if (_squashButton.state == NSOnState) {
        strat = PRMergeStrategySquash;
    } else {
        strat = PRMergeStrategyRebase;
    }
    
    [self.delegate mergeViewController:self didSubmitWithTitle:[_titleField.stringValue trim] message:[_messageView.string trim] strategy:strat];
}

@end

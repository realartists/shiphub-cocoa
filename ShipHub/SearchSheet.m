//
//  SearchSheet.m
//  ShipHub
//
//  Created by James Howard on 7/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "SearchSheet.h"

#import "CustomQuery.h"
#import "Extras.h"
#import "SearchEditorViewController.h"
#import "SearchResultsController.h"
#import "DataStore.h"

@interface SearchSheet () <SearchEditorViewControllerDelegate, NSTextFieldDelegate>

@property IBOutlet NSTextField *queryNameLabel;
@property IBOutlet NSTextField *queryNameField;
@property IBOutlet NSButton *queryHelpButton;
@property IBOutlet SearchEditorViewController *searchEditorController;

@property IBOutlet NSButton *resultsDisclosure;
@property IBOutlet NSTextField *countField;
@property IBOutlet SearchResultsController *resultsController;

@property IBOutlet NSView *searchView;
@property IBOutlet NSView *resultsView;

@property IBOutlet NSButton *cancelButton;
@property IBOutlet NSButton *okButton;

@property IBOutlet FlippedView *container;

@end

@implementation SearchSheet

- (NSString *)windowNibName {
    return @"SearchSheet";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.window.contentView.autoresizesSubviews = NO;
    
    _okButton.enabled = NO;
    _queryNameField.delegate = self;
    
    _countField.stringValue = @"";
    
    _container.autoresizesSubviews = NO;
    _searchEditorController.delegate = self;
    
    _searchView.autoresizesSubviews = NO;
    [_searchView addSubview:_searchEditorController.view];
    
    _resultsView.autoresizesSubviews = NO;
    _resultsView.layer.borderColor = [[NSColor lightGrayColor] CGColor];
    _resultsView.layer.borderWidth = 1.0;
    [_resultsView addSubview:_resultsController.view];
    
    [self updateFromQuery];
    [self layoutWindow:NO];
    [self updateResults];
}

- (void)updateFromQuery {
    if (_query) {
        _queryNameField.stringValue = _query.title;
        _searchEditorController.predicate = _query.predicate;
        _okButton.enabled = _query.title.length > 0;
    }
}

- (void)setQuery:(CustomQuery *)query {
    _query = query;
    if ([self isWindowLoaded]) {
        [self updateFromQuery];
        [self updateResults];
    }
}

- (void)layoutWindow:(BOOL)display {
    // layout from top to bottom, then size window appropriately.
    
    if (display) {
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setAllowsImplicitAnimation:YES];
    }
    
    CGFloat xMarg = 18.0;
    CGFloat yGap = 13.0;
    CGFloat ySmGap = 3.0;
    CGFloat wFull = self.window.contentView.bounds.size.width;
    CGFloat w = wFull - (xMarg * 2.0);
    CGFloat yOff = yGap;
    CGFloat resultsHeight = 160.0;
    CGFloat resultsTotalHeight = resultsHeight + yGap;
    
    if (_resultsDisclosure.state == NSOffState) {
        resultsHeight = 0.0;
        resultsTotalHeight = 0.0;
    }
    
    CGFloat staticHeight = yGap + _queryHelpButton.frame.size.height + ySmGap + _countField.frame.size.height + 3.0 + resultsTotalHeight + _okButton.frame.size.height + yGap;
    
    CGFloat yMax = 400.0;
    if (display) {
        NSScreen *screen = self.window.screen;
        CGRect screenFrame = screen.visibleFrame;
        CGRect windowScreenRect = self.window.frame;
        CGFloat windowUpperY = CGRectGetMaxY(windowScreenRect);;
        yMax = windowUpperY;
        yMax -= screenFrame.origin.y; // subtract dock height (if any at bottom of screen)
        yMax -= yGap * 2.0; // subtract a bit of additional space
        yMax = MAX(yMax, 400.0);
    }
    
    CGFloat searchMaxHeight = yMax - staticHeight;
    
    // Top row: query name
    [_queryNameLabel sizeToFit];
    CGRect nameLabelRect = _queryNameLabel.frame;
    nameLabelRect.origin.x = xMarg;
    nameLabelRect.origin.y = yOff + 3.0;
    _queryNameLabel.frame = nameLabelRect;
    
    CGRect nameRect = _queryNameField.frame;
    nameRect.origin.x = CGRectGetMaxX(nameLabelRect) + 8.0;
    nameRect.origin.y = yOff;
    nameRect.size.width = wFull - nameRect.origin.x - 8.0 - _queryHelpButton.frame.size.width - xMarg;
    _queryNameField.frame = nameRect;
    
    CGRect helpRect = _queryHelpButton.frame;
    helpRect.origin.x = wFull - xMarg - helpRect.size.width;
    helpRect.origin.y = yOff;
    _queryHelpButton.frame = helpRect;
    
    yOff = CGRectGetMaxY(helpRect) + ySmGap;
    
    // Predicate Editor
    CGFloat searchHeight = ceil([_searchEditorController fullHeight]);
    searchHeight = MIN(searchHeight, searchMaxHeight);
    
    CGRect searchRect = CGRectMake(xMarg, yOff, w, searchHeight);
    _searchView.frame = searchRect;
    [NSAnimationContext performWithoutAnimation:^{
        _searchEditorController.view.frame = CGRectMake(0, 0, w, searchHeight);
    }];
    
    yOff = CGRectGetMaxY(searchRect) + yGap;
    
    // Results disclosure button and count label
    CGPoint resultsDisclosureOrigin = CGPointMake(xMarg, yOff);
    [_resultsDisclosure setFrameOrigin:resultsDisclosureOrigin];
    
    CGRect countFrame = _countField.frame;
    countFrame.origin.x = CGRectGetMaxX(_resultsDisclosure.frame) + 5.0;
    countFrame.origin.y = yOff;
    countFrame.size.width = wFull - countFrame.origin.x - xMarg;
    _countField.frame = countFrame;
    
    yOff = CGRectGetMaxY(countFrame) + 3.0;
    
    // Results table (drawn only if disclosure is open)
    CGRect resultsRect;
    if (_resultsDisclosure.state == NSOnState) {
        resultsRect = CGRectMake(xMarg, yOff, w, resultsHeight);
        _resultsView.frame = resultsRect;
        [NSAnimationContext performWithoutAnimation:^{
            _resultsController.view.frame = CGRectMake(0, 0, resultsRect.size.width, resultsRect.size.height);
        }];
        yOff = CGRectGetMaxY(resultsRect) + yGap;
    } else {
        resultsRect = CGRectMake(xMarg, yOff, w, 0.0);
        _resultsView.frame = resultsRect;
    }
    
    // Cancel and OK buttons
    CGRect okFrame = _okButton.frame;
    okFrame.origin.y = yOff;
    _okButton.frame = okFrame;
    
    CGRect cancelFrame = _cancelButton.frame;
    cancelFrame.origin.y = yOff;
    _cancelButton.frame = cancelFrame;
    
    yOff = CGRectGetMaxY(cancelFrame) + yGap;
    
    CGFloat titleToolbarHeight = self.window.titleToolbarHeight;
    
    CGSize windowSize = CGSizeMake(wFull, yOff);
    CGRect wFrame = self.window.frame;
    wFrame.origin.y += wFrame.size.height - windowSize.height;
    wFrame.size.height = windowSize.height + titleToolbarHeight;
    CGFloat duration = [self.window animationResizeTime:wFrame];
    [self.window setFrame:wFrame display:display];
    [NSAnimationContext performWithoutAnimation:^{
        _container.frame = CGRectMake(0, 0, windowSize.width, windowSize.height);
    }];
    
    if (display) {
        [[NSAnimationContext currentContext] setDuration:duration];
        [NSAnimationContext endGrouping];
    }
}

- (IBAction)submit:(id)sender {
    CustomQuery *query = self.query ?: [CustomQuery new];
    
    query.title = [_queryNameField.stringValue trim];
    query.predicate = _searchEditorController.predicate;
    
    _query = query;
    
    [[DataStore activeStore] saveQuery:query completion:nil];
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)cancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (IBAction)disclosureToggled:(id)sender {
    [self layoutWindow:YES];
}

- (IBAction)showHelp:(id)sender {
    [_searchEditorController helpButtonClicked:sender];
}

- (void)searchEditorViewControllerDidChangePredicate:(SearchEditorViewController *)vc {
    [self updateResults];
}

- (void)searchEditorViewControllerDidChangeFullHeight:(SearchEditorViewController *)vc {
    if ([self.window isVisible]) {
        [self layoutWindow:YES];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj {
    _okButton.enabled = [[_queryNameField.stringValue trim] length] > 0;
}

- (void)beginSheetModalForWindow:(NSWindow *)sheetWindow completionHandler:(void (^)(CustomQuery *query))handler {
    // create a retain cycle on self to keep us alive until we are dismissed.
    [sheetWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        if (handler) handler(self.query);
    }];
}

- (void)updateResults {
    [[DataStore activeStore] countIssuesMatchingPredicate:_searchEditorController.predicate completion:^(NSUInteger count, NSError *error) {
        NSString *label = nil;
        if (count == 1) {
            label = NSLocalizedString(@"1 Matching Issue", nil);
        } else {
            label = [NSString localizedStringWithFormat:NSLocalizedString(@"%tu Matching Issues", nil), count];
        }
        _countField.stringValue = label;
    }];
    
    _resultsController.predicate = _searchEditorController.predicate;
}

@end

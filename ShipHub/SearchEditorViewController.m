//
//  SearchEditorViewController.m
//  Ship
//
//  Created by James Howard on 7/23/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SearchEditorViewController.h"

#import "Extras.h"
#import "SearchEditor.h"

@interface SearchEditorViewController ()

@property IBOutlet SearchEditor *editor;

@property IBOutlet NSView *topView;

@property NSPredicate *lastPredicate;

@end

@implementation SearchEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(predicateEditorDidChange:) name:NSRuleEditorRowsDidChangeNotification object:_editor];
    
    [_editor addObserver:self forKeyPath:@"predicate" options:0 context:NULL];
}

- (void)dealloc {
    [_editor removeObserver:self forKeyPath:@"predicate" context:NULL];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CGFloat)fullHeight {
    [self view];
    
    CGFloat height = ((CGFloat)(_editor.numberOfRows) * _editor.rowHeight + _topView.bounds.size.height) - 1.0;
    
    return height;
}

- (IBAction)helpButtonClicked:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Query Editor Help", @"For your information");
    alert.informativeText = NSLocalizedString(@"To build complex queries, hold down the option (⎇) key in the query editor and click the plus button.", nil);
    alert.icon = [NSImage imageNamed:NSImageNameInfo];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert runModal];
}

- (void)hideScrollers {
    [[_editor enclosingScrollView] setHasVerticalScroller:NO];
}

- (void)showScrollers {
    [[_editor enclosingScrollView] setHasVerticalScroller:YES];
}

- (void)reset {
    [_editor reset];
}

static BOOL s_inPredicate = NO;

- (NSPredicate *)predicate {
    s_inPredicate = YES;
    NSPredicate *p = [_editor predicate];
    s_inPredicate = NO;
    return p;
}

- (void)setPredicate:(NSPredicate *)predicate {
    [self view];
    _lastPredicate = predicate;
    s_inPredicate = YES;
    [_editor assignPredicate:predicate];
    s_inPredicate = NO;
}

static BOOL s_inObserve = NO;
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _editor && [keyPath isEqualToString:@"predicate"]) {
        if (s_inPredicate || s_inObserve) return;
        s_inObserve = YES;
        NSPredicate *predicate = [_editor predicate];
        if (![_lastPredicate isEqual:predicate]) {
            _lastPredicate = predicate;
            [_delegate searchEditorViewControllerDidChangePredicate:self];
        }
        s_inObserve = NO;
    }
}

- (void)predicateEditorDidChange:(NSNotification *)notification {
    [_delegate searchEditorViewControllerDidChangeFullHeight:self];
    NSScrollView *scroll = [_editor enclosingScrollView];
    CGRect docRect = [scroll documentVisibleRect];
    CGRect bounds = [_editor bounds];
    
    if (((bounds.size.height - docRect.size.height) - docRect.origin.y) < _editor.rowHeight) {
        // should scroll to bottom
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [scroll scrollToEndOfDocument:self];
        });
    }
}

- (void)addCompoundPredicate:(id)sender {
    [_editor addCompoundPredicate];
}

@end

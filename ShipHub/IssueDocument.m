//
//  IssueDocument.m
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueDocument.h"

#import "Extras.h"
#import "Issue.h"

@implementation IssueDocument

- (NSString *)windowNibName {
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"IssueDocument";
}

- (NSString *)defaultDraftName {
    return NSLocalizedString(@"New Issue", nil);
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    id issueIdentifier = _issueViewController.issue.fullIdentifier;
    if (issueIdentifier) {
        DebugLog(@"Encoding %@", issueIdentifier);
        [coder encodeObject:issueIdentifier forKey:@"IssueIdentifier"];
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    aController.contentViewController = self.issueViewController;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self.issueViewController addObserver:self forKeyPath:@"title" options:0 context:NULL];
}

- (void)dealloc {
    [self.issueViewController removeObserver:self forKeyPath:@"title"];
}

- (NSWindow *)documentWindow {
    return [[[self windowControllers] firstObject] window];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (object == _issueViewController && [keyPath isEqualToString:@"title"]) {
        [[self documentWindow] setTitle:_issueViewController.title];
    }
}

- (void)updateChangeCount:(NSDocumentChangeType)change {
    // FIXME: Make this work right!
    // for now, disable change tracking
}

@end

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
#import "IssueIdentifier.h"

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

- (void)updateDocumentName {
    NSString *docName = _issueViewController.title ?: [self defaultDraftName];
    [self setDisplayName:docName];
    NSWindow *docWindow = [self documentWindow];
    docWindow.title = docName;
    docWindow.representedURL = [_issueViewController.issue.fullIdentifier issueGitHubURL];
    [[[self documentWindow] standardWindowButton:NSWindowDocumentIconButton] setImage:[NSImage imageNamed:@"AppIcon"]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (object == _issueViewController && [keyPath isEqualToString:@"title"]) {
        [self updateDocumentName];
    }
}

- (void)updateChangeCount:(NSDocumentChangeType)change {
    // FIXME: Make this work right!
    // for now, disable change tracking
}

#pragma mark -

- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu {
    return NO;
}

- (BOOL)window:(NSWindow *)window shouldDragDocumentWithEvent:(NSEvent *)event from:(NSPoint)dragImageLocation withPasteboard:(NSPasteboard *)pasteboard
{
    if (_issueViewController.issue.fullIdentifier) {
        [_issueViewController.issue.fullIdentifier copyIssueIdentifierToPasteboard:pasteboard];
        NSButton *button = [window standardWindowButton:NSWindowDocumentIconButton];
        CGPoint buttonInWindow = [button convertPoint:CGPointMake(0.0, button.frame.size.height) toView:nil];
        NSImage *image = [[button image] copy];
        image.size = button.frame.size;
        
        [window dragImage:image at:buttonInWindow offset:CGSizeZero event:event pasteboard:pasteboard source:self slideBack:YES];
        return NO; // NO because we're handling the drag ourselves in order to get the image right. NSWindow will draw the wrong icon otherwise.
    } else {
        return NO;
    }
}

@end

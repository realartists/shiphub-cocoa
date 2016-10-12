//
//  PRDocument.m
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRDocument.h"

@implementation PRDocument

- (NSString *)windowNibName {
    return @"PRDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    aController.contentViewController = self.prViewController;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    [self.prViewController addObserver:self forKeyPath:@"title" options:0 context:NULL];
}

- (void)dealloc {
    [self.prViewController removeObserver:self forKeyPath:@"title"];
}

- (NSWindow *)documentWindow {
    return [[[self windowControllers] firstObject] window];
}

- (void)needsSaveChanged:(NSNotification *)note {
    //[[self documentWindow] setDocumentEdited:[note.userInfo[IssueViewControllerNeedsSaveKey] boolValue]];
}

- (void)updateDocumentName {
    NSString *docName = _prViewController.title ?: [self defaultDraftName];
    [self setDisplayName:docName];
    NSWindow *docWindow = [self documentWindow];
    docWindow.title = docName;
    docWindow.representedURL = [_prViewController.pr gitHubFilesURL];
    [[[self documentWindow] standardWindowButton:NSWindowDocumentIconButton] setImage:[NSImage imageNamed:@"AppIcon"]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if (object == _prViewController && [keyPath isEqualToString:@"title"]) {
        [self updateDocumentName];
    }
}

@end

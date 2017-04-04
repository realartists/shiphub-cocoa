//
//  PRDocument.m
//  ShipHub
//
//  Created by James Howard on 10/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRDocument.h"

#import "Extras.h"

@interface PRDocumentWindow : NSWindow

@end

@implementation PRDocumentWindow

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    [super setFrame:frameRect display:flag];
}

@end

@implementation PRDocument

- (NSString *)windowNibName {
    return @"PRDocument";
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if (menuItem.action == @selector(saveDocument:)) {
        return NO; // you can't save a PRDocument.
    }
    return YES;
}

- (void)makeWindowControllers {
    [super makeWindowControllers];
    
    NSWindowController *aController = [[self windowControllers] firstObject];
    NSWindow *window = aController.window;
    NSScreen *screen = window.screen ?: [NSScreen mainScreen];
    aController.contentViewController = self.prViewController;
    [window setFrame:screen.visibleFrame display:NO];
    [window setToolbar:self.prViewController.toolbar];
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

- (IBAction)saveDocument:(id)sender {
    // no-op
}

- (void)updateChangeCount:(NSDocumentChangeType)change {
    // don't bother with change tracking
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

#pragma mark -

- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu {
    return NO;
}

- (BOOL)window:(NSWindow *)window shouldDragDocumentWithEvent:(NSEvent *)event from:(NSPoint)dragImageLocation withPasteboard:(NSPasteboard *)pasteboard
{
    if (_prViewController.pr.issue.fullIdentifier) {
        NSURL *URL = [_prViewController.pr gitHubFilesURL];
        
        [pasteboard clearContents];
        NSAttributedString *attrStr = [[NSAttributedString alloc] initWithString:_prViewController.pr.issue.fullIdentifier attributes:@{NSLinkAttributeName: URL}];
        [pasteboard writeObjects:@[[MultiRepresentationPasteboardData representationWithArray:@[attrStr, URL]]]];

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

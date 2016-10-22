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
#import "IssueDocumentController.h"

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
    SEL setTabbingIdentifier = NSSelectorFromString(@"setTabbingIdentifier:");
    if ([aController.window respondsToSelector:setTabbingIdentifier]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [aController.window performSelector:setTabbingIdentifier withObject:@"IssueDocument"];
#pragma clang diagnostic pop
    }
    aController.contentViewController = self.issueViewController;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(needsSaveChanged:) name:IssueViewControllerNeedsSaveDidChangeNotification object:self.issueViewController];
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

- (void)needsSaveChanged:(NSNotification *)note {
    [[self documentWindow] setDocumentEdited:[note.userInfo[IssueViewControllerNeedsSaveKey] boolValue]];
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
    // Change tracking is done within the Javascript code.
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(nullable SEL)shouldCloseSelector contextInfo:(nullable void *)contextInfo
{
    if (![self.issueViewController needsSave]) {
        // OK to close. There's nothing to save.
        NSInvocation *iv = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:shouldCloseSelector]];
        
        iv.target = delegate;
        iv.selector = shouldCloseSelector;
        id arg2 = self;
        BOOL arg3 = YES;
        void *arg4 = contextInfo;
        [iv setArgument:&arg2 atIndex:2];
        [iv setArgument:&arg3 atIndex:3];
        [iv setArgument:&arg4 atIndex:4];
        
        [iv invoke];
        
        return;
    }
    
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Do you want to save the changes made to the document “%@”?", nil), self.displayName ?: NSLocalizedString(@"Untitled", nil)];
    NSString *subtitle = NSLocalizedString(@"Your changes will be lost if you don’t save them.", nil);
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = subtitle;
    [alert addButtonWithTitle:NSLocalizedString(@"Save", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    NSButton *dontSave = [alert addButtonWithTitle:NSLocalizedString(@"Don't Save", nil)];
    dontSave.keyEquivalent = @"d";
    
    // shouldCloseSelector: - (void)document:(NSDocument *)document shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo;
    
    [alert beginSheetModalForWindow:[self documentWindow] completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            // Save
            [self saveDocumentWithDelegate:delegate didSaveSelector:shouldCloseSelector contextInfo:contextInfo];
        } else if (returnCode == NSAlertSecondButtonReturn) {
            // Cancel
        } else if (returnCode == NSAlertThirdButtonReturn) {
            // Don't Save
            NSInvocation *iv = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:shouldCloseSelector]];
            
            iv.target = delegate;
            iv.selector = shouldCloseSelector;
            id arg2 = self;
            BOOL arg3 = YES;
            void *arg4 = contextInfo;
            [iv setArgument:&arg2 atIndex:2];
            [iv setArgument:&arg3 atIndex:3];
            [iv setArgument:&arg4 atIndex:4];
            
            [iv invoke];
        } else {
            // Wha?
            NSAssert(NO, @"Unexpected sheet return");
        }
    }];
}

- (void)saveDocumentWithDelegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
    [self.issueViewController saveWithCompletion:^(NSError *error) {
        // - (void)document:(NSDocument *)document didSave:(BOOL)didSaveSuccessfully contextInfo:(void *)contextInfo;
        NSInvocation *iv = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:didSaveSelector]];
        
        iv.target = delegate;
        iv.selector = didSaveSelector;
        id arg2 = self;
        BOOL arg3 = error == nil;
        void *arg4 = contextInfo;
        [iv setArgument:&arg2 atIndex:2];
        [iv setArgument:&arg3 atIndex:3];
        [iv setArgument:&arg4 atIndex:4];
        
        [iv invoke];
    }];
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

#pragma mark -

- (void)newWindowForTab:(id)sender {
    [[IssueDocumentController sharedDocumentController] newDocument:sender];
}

@end

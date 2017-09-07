//
//  WebFindBarController.m
//  ShipHub
//
//  Created by James Howard on 3/21/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "WebFindBarController.h"

#import "Extras.h"

@interface WebFindBarController ()

@property IBOutlet NSSearchField *searchField;

@end

@implementation WebFindBarController

- (IBAction)performFindPanelAction:(id)sender {
    [self performFindAction:[sender tag]];
}

- (IBAction)performTextFinderAction:(nullable id)sender {
    [self performFindAction:[sender tag]];
}

- (void)performFindAction:(NSInteger)tag {
    switch (tag) {
        case NSTextFinderActionShowFindInterface:
            self.viewContainer.findBarView = self.view;
            self.viewContainer.findBarVisible = YES;
            _searchField.stringValue = [self readFindPasteboard];
            [_searchField.window makeFirstResponder:_searchField];
            [self searchFieldAction:nil];
            break;
        case NSTextFinderActionNextMatch:
            [self.delegate findBarControllerGoNext:self];
            break;
        case NSTextFinderActionPreviousMatch:
            [self.delegate findBarControllerGoPrevious:self];
            break;
        case NSTextFinderActionSetSearchString: {
            [self.delegate findBarController:self selectedTextForFind:^(NSString *text) {
                [self updateFindPasteboard:text];
                [_searchField setStringValue:text];
                if (self.viewContainer.findBarVisible) {
                    [self searchFieldAction:nil];
                }
            }];
            break;
        }
        case NSTextFinderActionHideFindInterface:
            if (self.viewContainer.findBarVisible) {
                self.viewContainer.findBarVisible = NO;
                _searchField.stringValue = @"";
                [self searchFieldAction:nil];
            }
            break;
    }
}

- (void)hide {
    [self performFindAction:NSTextFinderActionHideFindInterface];
}

- (IBAction)searchFieldAction:(id)sender {
    [self.delegate findBarController:self searchFor:[_searchField.stringValue trim]];
}

- (IBAction)navigate:(id)sender {
    NSSegmentedControl *seg = sender;
    if (seg.selectedSegment == 0) {
        [self performFindAction:NSTextFinderActionPreviousMatch];
    } else {
        [self performFindAction:NSTextFinderActionNextMatch];
    }
}

- (IBAction)done:(id)sender {
    [self hide];
}

- (void)updateFindPasteboard:(NSString *)text {
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSFindPboard];
    [pboard clearContents];
    [pboard writeObjects:@[text?:@""]];
}

- (NSString *)readFindPasteboard {
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSFindPboard];
    return [pboard stringForType:NSPasteboardTypeString] ?: @"";
}

@end

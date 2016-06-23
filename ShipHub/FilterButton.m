//
//  FilterButton.m
//  ShipHub
//
//  Created by James Howard on 6/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "FilterButton.h"

@interface FilterButton () <NSMenuDelegate> {
    NSMenu *_myMenu;
    BOOL _menuShowing;
}

@end

@implementation FilterButton

- (id)initWithFrame:(NSRect)frameRect {
    return [self initWithFrame:frameRect pullsDown:YES];
    
}

- (id)initWithFrame:(NSRect)buttonFrame pullsDown:(BOOL)flag {
    if (self = [super initWithFrame:buttonFrame pullsDown:flag]) {
        [self commonFilterButtonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self commonFilterButtonInit];
    }
    return self;
}

- (void)commonFilterButtonInit {
    NSPopUpButtonCell *cell = self.cell;
    cell.arrowPosition = NSPopUpArrowAtBottom;
    cell.altersStateOfSelectedItem = NO;
    cell.usesItemFromMenu = NO;
    self.autoenablesItems = YES;
    self.controlSize = NSSmallControlSize;
    self.state = NSOnState;
    self.preferredEdge = NSRectEdgeMinY;
    [self setButtonType:NSPushOnPushOffButton];
    self.font = [NSFont systemFontOfSize:10.0];
    self.bezelStyle = NSRecessedBezelStyle;
    self.showsBorderOnlyWhileMouseInside = YES;
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self addTrackingRect:self.bounds owner:self userData:NULL assumeInside:NO];
}

- (void)sizeToFit {
    [super sizeToFit];
    CGRect f = self.frame;
    f.size.width -= 14.0; // for some reason NSPopUpButton wants to put the chevron too far right. Stop that shit.
    self.frame = f;
}

- (void)setFilterEnabled:(BOOL)filterEnabled {
    _filterEnabled = filterEnabled;
    self.showsBorderOnlyWhileMouseInside = !filterEnabled;
}

- (void)mouseEntered:(NSEvent *)theEvent {
    [super mouseEntered:theEvent];
    if (_filterEnabled) self.alphaValue = 0.7;
}

- (void)mouseExited:(NSEvent *)theEvent {
    [super mouseExited:theEvent];
    self.alphaValue = 1.0;
}

- (void)setTitle:(NSString *)title {
    NSPopUpButtonCell *cell = self.cell;
    [super setTitle:title];
    [cell setTitle:title];
    NSMenuItem *i = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    [cell setMenuItem:i];
}

- (void)showMenu {
    self.menu.minimumWidth = self.bounds.size.width;
    self.menu.font = self.font;
    [self.menu popUpMenuPositioningItem:nil atLocation:CGPointMake(0, self.bounds.size.height + 3.0) inView:self];
}

- (void)performClick:(id)sender {
    [self showMenu];
}

- (void)mouseDown:(NSEvent *)theEvent {
    [self showMenu];
}

- (void)setMenu:(NSMenu *)menu {
    if (_myMenu != menu) {
        BOOL menuShowing = _menuShowing;
        _myMenu.delegate = nil;
        if (menuShowing) {
            [_myMenu cancelTrackingWithoutAnimation];
        }
        _myMenu = menu;
        _myMenu.delegate = self;
        if (menuShowing) {
            [self showMenu];
        }
    }
}

- (NSMenu *)menu {
    return _myMenu;
}

- (void)menuWillOpen:(NSMenu *)menu {
    _menuShowing = YES;
}

- (void)menuDidClose:(NSMenu *)menu {
    _menuShowing = NO;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p \"%@\">", NSStringFromClass([self class]), self, self.title];
}

@end

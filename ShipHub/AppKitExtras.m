//
//  AppKitExtras.m
//  Ship
//
//  Created by James Howard on 9/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "AppKitExtras.h"
#import "FoundationExtras.h"

@implementation NSTextView (Extras)

- (CGFloat)heightForWidth:(CGFloat)width {
    CGSize insets = self.textContainerInset;
    
    CGSize oldSize = self.frame.size;
    CGSize newSize = oldSize;
    newSize.width = width;
    [self setFrameSize:newSize];
    
    NSTextContainer *textContainer = self.textContainer;
    
    NSLayoutManager *layoutManager = self.layoutManager;
    
    [layoutManager glyphRangeForTextContainer:textContainer];
    [layoutManager ensureLayoutForTextContainer:textContainer];
    
    NSRect usedRect = [layoutManager usedRectForTextContainer:textContainer];
    
    [self setFrameSize:oldSize];
    
    return usedRect.size.height + insets.height;
}

@end

@implementation NSText (Extras)

- (BOOL)isEnabled {
    return self.editable;
}

- (void)setEnabled:(BOOL)enabled {
    self.editable = enabled;
}

@end

@implementation NSEvent (Extras)

- (unichar)functionKey {
    NSString*   const   character   =   [self charactersIgnoringModifiers];
    unichar     const   code        =   [character characterAtIndex:0];
    
    return code;
}

- (BOOL)isArrowDown {
    return self.functionKey == NSDownArrowFunctionKey;
}
- (BOOL)isArrowUp {
    return self.functionKey == NSUpArrowFunctionKey;
}
- (BOOL)isArrowLeft {
    return self.functionKey == NSLeftArrowFunctionKey;
}
- (BOOL)isArrowRight {
    return self.functionKey == NSRightArrowFunctionKey;
}
- (BOOL)isPageUp {
    return self.functionKey == NSPageUpFunctionKey;
}
- (BOOL)isPageDown {
    return self.functionKey == NSPageDownFunctionKey;
}
- (BOOL)isPageHome {
    return self.functionKey == NSHomeFunctionKey;
}
- (BOOL)isPageEnd {
    return self.functionKey == NSEndFunctionKey;
}

- (BOOL)isTabKey {
    return self.keyCode == 48;
}

- (BOOL)isShiftTab {
    return [self isTabKey] && ([self modifierFlagsAreExclusively:NSShiftKeyMask] || [self modifierFlagsAreExclusively:NSAlphaShiftKeyMask]);
}

- (BOOL)isSpace {
    return self.keyCode == 49;
}

- (BOOL)isDelete {
    unichar key = [[self charactersIgnoringModifiers] characterAtIndex:0];
    return key == NSDeleteCharacter;
}

- (BOOL)modifierFlagsAreExclusively:(NSEventModifierFlags)flags {
    NSEventModifierFlags mflags = [self modifierFlags];
    NSEventModifierFlags all = NSAlphaShiftKeyMask | NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask | NSNumericPadKeyMask | NSHelpKeyMask | NSFunctionKeyMask;
    mflags &= all;
    return flags == mflags;
}

- (BOOL)isReturn {
    unichar key = [[self charactersIgnoringModifiers] characterAtIndex:0];
    return key == NSCarriageReturnCharacter || key == NSFormFeedCharacter || key == NSEnterCharacter || key == NSNewlineCharacter || key == NSLineSeparatorCharacter;
}

@end

@implementation NSScrollView (Extras)

- (void)scrollLineUp:(id)sender {
    CGPoint p = [self documentVisibleRect].origin;
    p.y -= self.verticalLineScroll;
    [[self documentView] scrollPoint:p];
}

- (void)scrollLineDown:(id)sender {
    CGPoint p = [self documentVisibleRect].origin;
    p.y += self.verticalLineScroll;
    [[self documentView] scrollPoint:p];
}

- (void)scrollPageUp:(id)sender {
    CGPoint p = [self documentVisibleRect].origin;
    p.y -= self.verticalPageScroll;
    [[self documentView] scrollPoint:p];
}

- (void)scrollPageDown:(id)sender {
    CGPoint p = [self documentVisibleRect].origin;
    p.y += self.verticalPageScroll;
    [[self documentView] scrollPoint:p];
}

- (void)scrollToEndOfDocument:(id)sender {
    NSPoint newScrollOrigin;
    
    newScrollOrigin=NSMakePoint(0.0,NSMaxY([[self documentView] frame])
                                -NSHeight([[self contentView] bounds]));
    
    [[self documentView] scrollPoint:newScrollOrigin];
}

- (void)scrollToBeginningOfDocument:(id)sender {
    NSPoint newScrollOrigin;
    
    newScrollOrigin=NSMakePoint(0.0,0.0);
    
    [[self documentView] scrollPoint:newScrollOrigin];
}

@end

@implementation NSView (Extras)

- (BOOL)isFirstResponder {
    return [[self window] firstResponder] == self;
}

- (void)Extras_disableAllControls:(NSMutableArray *)accum {
    for (NSView *subview in [self subviews]) {
        if ([subview isKindOfClass:[NSControl class]] || [subview isKindOfClass:[NSText class]]) {
            id c = (id)subview;
            if ([c isEnabled]) {
                [c setEnabled:NO];
                [accum addObject:c];
            }
        }
        [subview Extras_disableAllControls:accum];
    }
}

- (NSArray *)disableAllControls {
    NSMutableArray *accum = [NSMutableArray array];
    [self Extras_disableAllControls:accum];
    return accum;
}

- (void)setContentView:(NSView *)subview {
    subview.frame = self.bounds;
    subview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.autoresizesSubviews = YES;
    [self setSubviews:@[subview]];
}

- (void)enumerateChildViewsOfClass:(Class)type handler:(void (^)(id view, BOOL *stop))handler {
    BOOL stop = NO;
    for (id subview in [self subviews]) {
        if ([subview isKindOfClass:type]) {
            handler(subview, &stop);
            if (stop) {
                return;
            }
        }
        [subview enumerateChildViewsOfClass:type handler:handler];
    }
}

@end

@implementation NSToolbar (Extras)

- (id)itemWithIdentifier:(NSString *)identifier {
    for (NSToolbarItem *item in self.items) {
        if ([item.itemIdentifier isEqualToString:identifier]) {
            return item;
        }
    }
    return nil;
}

@end

@implementation NSPopUpButton (Extras)

- (void)selectItemMatchingPredicate:(NSPredicate *)predicate {
    for (NSMenuItem *item in self.itemArray) {
        if ([predicate evaluateWithObject:item]) {
            [self selectItem:item];
            return;
        }
    }
    [self selectItem:nil];
}

@end


@implementation BaselineAdjustableTextAttachmentCell {
    NSPoint myBaselineOffset;
}

- (void)setCellBaselineOffset:(NSPoint)p {
    myBaselineOffset = p;
}

- (NSPoint)cellBaselineOffset {
    return myBaselineOffset;
}

@end

@implementation KeyboardNavigablePopupButton

- (BOOL)canBecomeKeyView { return YES; }

- (void)keyDown:(NSEvent *)theEvent {
    if ([theEvent isArrowDown] || [theEvent isArrowUp]) {
        [self performClick:nil];
        return;
    }
    [super keyDown:theEvent];
}

// ship://Problems/212 <Right aligned PropertiesController popup views are weird>
- (void)showMenu {
    self.menu.minimumWidth = self.bounds.size.width;
    self.menu.font = self.font;
    [self.menu popUpMenuPositioningItem:self.selectedItem atLocation:CGPointZero inView:self];
}

- (void)performClick:(id)sender {
    [self showMenu];
}

- (void)mouseDown:(NSEvent *)theEvent {
    [self showMenu];
}

@end

@implementation NSPasteboard (Extras)

- (void)writeURL:(NSURL *)URL {
    [self writeURL:URL string:[URL description]];
}

- (void)writeURL:(NSURL *)URL string:(NSString *)string {
    if (!URL) return;
    if (!string) string = [URL description];
    [self writeObjects:@[string, URL]];
}

@end

@implementation TiledImageView

- (BOOL)wantsLayer { return YES; }

- (void)setImage:(NSImage *)image {
    _image = image;
    self.layer.backgroundColor = [[NSColor colorWithPatternImage:image] CGColor];
}

@end


@implementation NSImage (Extras)

- (void)constrainToMaxEdge:(CGFloat)maxEdge {
    NSSize size = self.size;
    if (size.width < maxEdge && size.height < maxEdge) {
        return;
    } else if (size.width > size.height) {
        CGFloat newWidth = maxEdge;
        size.height *= (newWidth / size.width);
        size.width = newWidth;
    } else {
        CGFloat newHeight = maxEdge;
        size.width *= (newHeight / size.height);
        size.height = newHeight;
    }
    self.size = size;
}

- (NSImage *)imageConstrainedToMaxEdge:(CGFloat)maxEdge {
    NSImage *i = [self copy];
    [i constrainToMaxEdge:maxEdge];
    return i;
}

- (NSImage *)renderWithColor:(NSColor *)color {
    CGSize size = self.size;
    NSImage *image = [self copy];
    [image lockFocus];
    
    [color set];
    NSRectFillUsingOperation(NSMakeRect(0, 0, size.width, size.height), NSCompositeSourceAtop);
    
    [image unlockFocus];
    
    return image;
}

@end

@implementation NSColor (Extras)

+ (NSColor *)extras_controlBlue {
    static dispatch_once_t onceToken;
    static NSColor *color;
    dispatch_once(&onceToken, ^{
        color = [NSColor colorWithDeviceRed:(0x00 / 255.0) green:(0x85 / 255.0) blue:(0xE4 / 255.0) alpha:1.0];
    });
    return color;
}

+ (NSColor *)extras_outlineGray {
    static dispatch_once_t onceToken;
    static NSColor *color;
    dispatch_once(&onceToken, ^{
        color = [NSColor colorWithDeviceRed:(0x77 / 255.0) green:(0x77 / 255.0) blue:(0x77 / 255.0) alpha:1.0];
    });
    return color;
}

+ (NSColor *)ra_orange {
    static dispatch_once_t onceToken;
    static NSColor *color;
    dispatch_once(&onceToken, ^{
        color = [NSColor colorWithRed:1.0 green:0.325 blue:0.208 alpha:1.0];
    });
    return color;
}

+ (NSColor *)ra_beige {
    static dispatch_once_t onceToken;
    static NSColor *color;
    dispatch_once(&onceToken, ^{
        color = [NSColor colorWithRed:0.875 green:0.875 blue:0.831 alpha:1.0];
    });
    return color;
}

+ (NSColor *)ra_teal {
    static dispatch_once_t onceToken;
    static NSColor *color;
    dispatch_once(&onceToken, ^{
        color = [NSColor colorWithRed:0.243 green:0.573 blue:0.639 alpha:1.0];
    });
    return color;
}

+ (NSColor *)ra_slate {
    static dispatch_once_t onceToken;
    static NSColor *color;
    dispatch_once(&onceToken, ^{
        color = [NSColor colorWithRed:0.208 green:0.224 blue:0.251 alpha:1.0];
    });
    return color;
}

+ (NSColor *)colorWithHexString:(NSString *)hexString {
    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringWithRange:NSMakeRange(1, hexString.length-1)];
    }
    
    if ([hexString length] == 3) {
        hexString = [NSString stringWithFormat:@"%C%C%C%C%C%C",
                     [hexString characterAtIndex:0],
                     [hexString characterAtIndex:0],
                     [hexString characterAtIndex:1],
                     [hexString characterAtIndex:1],
                     [hexString characterAtIndex:2],
                     [hexString characterAtIndex:2]];
    }
    
    if ([hexString length] == 6) {
        hexString = [hexString stringByAppendingString:@"00"];
    }
    
    NSScanner *s = [NSScanner scannerWithString:hexString];
    uint32_t c = 0;
    if ([s scanHexInt:&c]) {
        CGFloat r = (uint8_t)(c >> 24) / 255.0;
        CGFloat g = (uint8_t)(c >> 16) / 255.0;
        CGFloat b = (uint8_t)(c >> 8) / 255.0;
        CGFloat a = (uint8_t)(c) / 255.0;
        
        return [NSColor colorWithRed:r green:g blue:b alpha:a];
    } else {
        return nil;
    }
}

- (NSString *)hexString {
    uint8_t r, g, b;
    CGFloat rf, gf, bf, af;
    [self getRed:&rf green:&gf blue:&bf alpha:&af];
    r = (rf * 255.0) / 1.0;
    g = (gf * 255.0) / 1.0;
    b = (bf * 255.0) / 1.0;
    return [NSString stringWithFormat:@"%02x%02x%02x", r, g, b];
}

@end

@implementation UndoManagerTextView {
    NSUndoManager *extras_undoManager;
}

- (void)setUndoManager:(NSUndoManager *)undoManager {
    extras_undoManager = undoManager;
}

- (NSUndoManager *)undoManager {
    if (extras_undoManager) {
        return extras_undoManager;
    } else {
        return [super undoManager];
    }
}

- (BOOL)becomeFirstResponder {
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder {
    [[self undoManager] removeAllActionsWithTarget:self.textStorage];
    return [super resignFirstResponder];
}

@end


@implementation NSFont (Extras)

+ (NSFont *)italicSystemFontOfSize:(CGFloat)fontSize {
    NSFont *font = [self systemFontOfSize:fontSize];
    return [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
}

@end

@implementation NSButton (Extras)

- (void)setTextColor:(NSColor *)color {
    NSMutableAttributedString *str = [self.attributedTitle mutableCopy];
    [str addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, str.length)];
    self.attributedTitle = str;
}

@end
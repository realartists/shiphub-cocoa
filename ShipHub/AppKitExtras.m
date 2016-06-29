//
//  AppKitExtras.m
//  Ship
//
//  Created by James Howard on 9/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "AppKitExtras.h"
#import "FoundationExtras.h"

#import <objc/runtime.h>

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

- (BOOL)isHiDPI {
    CGSize size = [self size];
    NSInteger w = size.width;
    NSInteger h = size.height;
    for (NSImageRep *rep in self.representations) {
        if (rep.pixelsWide > w || rep.pixelsHigh > h) {
            return YES;
        }
    }
    return NO;
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

+ (NSColor *)extras_tableSeparator {
    static dispatch_once_t onceToken;
    static NSColor *color;
    dispatch_once(&onceToken, ^{
        color = [NSColor colorWithWhite:0.898 alpha:1.0];
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
        hexString = [hexString stringByAppendingString:@"FF"];
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

- (BOOL)isDark {
    CGFloat r, g, b, a;
    [self getRed:&r green:&g blue:&b alpha:&a];
    
    CGFloat luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    
    return luma < 0.5;
}

- (NSColor *)colorByAdjustingBrightness:(CGFloat)amount {
    CGFloat h, s, b, a;
    [self getHue:&h saturation:&s brightness:&b alpha:&a];
    b *= amount;
    b = MIN(b, 1.0);
    b = MAX(b, 0.0);
    
    return [NSColor colorWithHue:h saturation:s brightness:b alpha:a];
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

@implementation MultiRepresentationPasteboardData {
    NSArray *_objs;
}

+ (id<NSPasteboardWriting>)representationWithArray:(NSArray<id<NSPasteboardWriting>> *)array {
    return [[self alloc] initWithArray:array];
}

- (id)initWithArray:(NSArray *)array {
    if (self = [super init]) {
        _objs = array;
    }
    return self;
}

- (NSArray<NSString *> *)writableTypesForPasteboard:(NSPasteboard *)pasteboard {
    
    NSMutableOrderedSet *s = [NSMutableOrderedSet new];
    for (id obj in _objs) {
        [s addObjectsFromArray:[obj writableTypesForPasteboard:pasteboard]];
    }
    
    return [s array];
}

- (id<NSPasteboardWriting>)pbObjForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    for (id obj in _objs) {
        if ([[obj writableTypesForPasteboard:pasteboard] containsObject:type]) {
            return obj;
        }
    }
    
    return nil;
}

- (NSPasteboardWritingOptions)writingOptionsForType:(NSString *)type pasteboard:(NSPasteboard *)pasteboard {
    return [[self pbObjForType:type pasteboard:pasteboard] writingOptionsForType:type pasteboard:pasteboard];
}

- (nullable id)pasteboardPropertyListForType:(NSString *)type {
    for (id obj in _objs) {
        id r = [obj pasteboardPropertyListForType:type];
        if (r) return r;
    }
    
    return nil;
}

@end

@implementation NSString (AppKitExtras)

- (void)drawWithTruncationInRect:(NSRect)rect attributes:(NSDictionary *)attrs {
    [[[NSAttributedString alloc] initWithString:self attributes:attrs] drawWithTruncationInRect:rect];
}

- (CGSize)multilineSizeThatFitsInSize:(CGSize)size attributes:(NSDictionary *)attrs {
    return [[[NSAttributedString alloc] initWithString:self attributes:attrs] multilineSizeThatFitsInSize:size];
}

@end

@implementation NSAttributedString (AppKitExtras)

static CGFloat GetAttachmentAscent(void *ref) {
    NSTextAttachment *att = (__bridge id)ref;
    return att.image.size.height;
}

static CGFloat GetAttachmentDescent(void *ref) {
    return 0.0;
}

static CGFloat GetAttachmentWidth(void *ref) {
    NSTextAttachment *att = (__bridge id)ref;
    return att.image.size.width;
}

- (void)drawWithTruncationInRect:(NSRect)rect {
    // On 10.11, this can be accomplished easily with NSStringDrawing API, but we need 10.10, so reimplement the API using CoreText.
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    if ([[NSGraphicsContext currentContext] isFlipped]) {
        // CoreText has to have the origin at the bottom left, so if we're flipped, unflip
        CGAffineTransform t = CGAffineTransformMakeTranslation(0.0, CGContextGetClipBoundingBox(ctx).size.height);
        t = CGAffineTransformScale(t, 1.0, -1.0);
        CGContextConcatCTM(ctx, t);
        
        rect = CGRectApplyAffineTransform(rect, t);
    }
    
    NSAttributedString *str = self;
    
    BOOL hasAtt = [self containsAttachments];
    
    if (hasAtt) {
        NSMutableAttributedString *delegateStr = [str mutableCopy];
        
        [str enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, str.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
            if (!value || range.length > 1) return;
            
            CTRunDelegateCallbacks callbacks = {
                kCTRunDelegateCurrentVersion,
                NULL, /* dealloc */
                GetAttachmentAscent,
                GetAttachmentDescent,
                GetAttachmentWidth
            };
            CTRunDelegateRef runDelegate = CTRunDelegateCreate(&callbacks, (__bridge void *)value);
            [delegateStr removeAttribute:NSAttachmentAttributeName range:range];
            [delegateStr addAttribute:(__bridge id)kCTRunDelegateAttributeName value:(__bridge id)runDelegate range:range];
            CFRelease(runDelegate);
        }];
        
        str = delegateStr;
    }
    
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    CGPathRef path = CGPathCreateWithRect(rect, NULL);
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)str);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, str.length), path, NULL);
    CFRelease(path);
    
    CFArrayRef lines = CTFrameGetLines(frame);
    NSUInteger lineCount = CFArrayGetCount(lines);
    
    if (lineCount == 0) {
        CFRelease(frame);
        CFRelease(framesetter);
        CGContextRestoreGState(ctx);
        return;
    }
    
    // Find out where all of our text attachments lie (if any)
    NSMutableArray *attLocations = hasAtt ? [NSMutableArray new] : nil;
    
    void (^noteAttLocations)(CTLineRef) = ^(CTLineRef line){
        if (hasAtt) {
            CFArrayRef runs = CTLineGetGlyphRuns(line);
            NSUInteger runCount = CFArrayGetCount(runs);
            for (NSUInteger j = 0; j < runCount; j++) {
                CTRunRef run = CFArrayGetValueAtIndex(runs, j);
                CFDictionaryRef attr = CTRunGetAttributes(run);
                if (CFDictionaryGetValue(attr, kCTRunDelegateAttributeName)) {
                    CGPoint origin = CGPointZero;
                    CTFrameGetLineOrigins(frame, CFRangeMake(j, 1), &origin);
                    origin.x += rect.origin.x;
                    origin.y += rect.origin.y;
                    
                    CFRange runRange = CTRunGetStringRange(run);
                    CGRect runBounds;
                    CGFloat ascent, descent;
                    runBounds.size.width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, NULL);
                    runBounds.size.height = ascent + descent;
                    
                    CGFloat xOffset = CTLineGetOffsetForStringIndex(line, runRange.location, NULL);
                    
                    runBounds.origin.x = origin.x + xOffset;
                    runBounds.origin.y = origin.y;
                    runBounds.origin.y -= descent;
                    
                    [attLocations addObject:[NSValue valueWithRect:runBounds]];
                }
            }
        }
    };
    
    // now draw up to maxLine
    for (NSUInteger i = 0; i < lineCount-1; i++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        noteAttLocations(line);
        CGPoint origin = CGPointZero;
        CTFrameGetLineOrigins(frame, CFRangeMake(i, 1), &origin);
        origin.x += rect.origin.x;
        origin.y += rect.origin.y;
        CGContextSetTextPosition(ctx, origin.x, origin.y);
        CTLineDraw(line, ctx);
    }
    
    // now draw the final line optionally with truncation
    {
        CTLineRef line = CFArrayGetValueAtIndex(lines, lineCount-1);
        noteAttLocations(line);
        
        CGPoint origin = CGPointZero;
        CTFrameGetLineOrigins(frame, CFRangeMake(lineCount-1, 1), &origin);
        origin.x += rect.origin.x;
        origin.y += rect.origin.y;
        CGContextSetTextPosition(ctx, origin.x, origin.y);
        
        CFRange lineRange = CTLineGetStringRange(line);
        
        if (lineRange.location + lineRange.length < str.length) {
            NSAttributedString *ellipsis = [[NSAttributedString alloc] initWithString:@"…" attributes:[str attributesAtIndex:lineRange.location effectiveRange:NULL]];
            
            CTLineRef truncChar = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)ellipsis);
            NSAttributedString *lastStr = [str attributedSubstringFromRange:NSMakeRange(lineRange.location, str.length-lineRange.location)];
            CTLineRef fullLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)lastStr);
            CTLineRef trunc = CTLineCreateTruncatedLine(fullLine, rect.size.width, kCTLineTruncationEnd, truncChar);
            CFRelease(truncChar);
            CTLineDraw(trunc, ctx);
            CFRelease(trunc);
            CFRelease(fullLine);
        } else {
            CTLineDraw(line, ctx);
        }
    }
    
    CFRelease(frame);
    CFRelease(framesetter);
    
    if ([attLocations count]) {
        __block NSUInteger k = 0;
        [self enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, self.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
            if (value) {
                NSTextAttachment *att = value;
                CGRect r = [attLocations[k] rectValue];
                NSDictionary *attrs = [self attributesAtIndex:range.location effectiveRange:NULL];
                CGFloat adj = [attrs[NSBaselineOffsetAttributeName] doubleValue];
                r.origin.y += adj;
                NSImage *img = [att image];
                [img drawInRect:r];
            }
        }];
    }
    
    CGContextRestoreGState(ctx);
}

- (CGSize)multilineSizeThatFitsInSize:(CGSize)size {
    NSAttributedString *str = self;
    
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    CGPathRef path = CGPathCreateWithRect(rect, NULL);
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)str);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, str.length), path, NULL);
    CFRelease(path);
    
    CFArrayRef lines = CTFrameGetLines(frame);
    NSUInteger lineCount = CFArrayGetCount(lines);
    
    if (lineCount == 0) {
        CFRelease(frame);
        CFRelease(framesetter);
        return CGSizeZero;
    }
    
    // now draw up to maxLine
    CGRect r = CGRectZero;
    for (NSUInteger i = 0; i < lineCount; i++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGPoint origin = CGPointZero;
        CTFrameGetLineOrigins(frame, CFRangeMake(i, 1), &origin);
        origin.y = size.height - origin.y;
        origin.x += rect.origin.x;
        origin.y += rect.origin.y;
        CGRect b = CTLineGetBoundsWithOptions(line, 0);
        b.origin = origin;
        r = CGRectUnion(r, b);
    }
    
    CFRelease(frame);
    CFRelease(framesetter);
    
    return r.size;
}

@end

@implementation NSSplitView (AppKitExtras)

- (void)setPosition:(CGFloat)position ofDividerAtIndex:(NSInteger)idx animated:(BOOL)animate
{
    if (!animate) {
        [self setPosition:position ofDividerAtIndex:idx];
        return;
    }
    
    NSTimer *existing = objc_getAssociatedObject(self, @"extras_animationTimer");
    if (existing) {
        [existing invalidate];
    }
    
    double start = CACurrentMediaTime();
    
    CGRect f = [[self subviews][idx] frame];
    CGFloat ipos = self.vertical ? CGRectGetWidth(f) : CGRectGetHeight(f);
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0/20.0 target:self selector:@selector(extras_animatePosition:) userInfo:@{@"start":@(start), @"pos":@(position), @"ipos":@(ipos), @"idx":@(idx)} repeats:YES];
    objc_setAssociatedObject(self, @"extras_animationTimer", timer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)extras_animatePosition:(NSTimer *)t {
    NSDictionary *info = t.userInfo;
    double now = CACurrentMediaTime();
    double start = [info[@"start"] doubleValue];
    double ipos = [info[@"ipos"] doubleValue];
    double position = [info[@"pos"] doubleValue];
    NSInteger idx = [info[@"idx"] integerValue];
    
    double frac = (now - start) / 0.3;
    
    if (frac >= 1.0) {
        [self setPosition:position ofDividerAtIndex:idx];
        [t invalidate];
        objc_setAssociatedObject(self, @"extras_animationTimer", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        double p = ipos + (position - ipos) * frac;
        [self setPosition:p ofDividerAtIndex:idx];
    }
}

@end

@implementation NSMenu (AppKitExtras)

- (BOOL)walkMenuItemsHelper:(void (^)(NSMenuItem *m, BOOL *stop))visitor {
    BOOL stop = NO;
    for (NSMenuItem *item in self.itemArray) {
        visitor(item, &stop);
        if (!stop && item.hasSubmenu) {
            stop = [item.submenu walkMenuItemsHelper:visitor];
        }
        if (stop) break;
    }
    return stop;
}

- (void)walkMenuItems:(void (^)(NSMenuItem *m, BOOL *stop))visitor {
    [self walkMenuItemsHelper:visitor];
    
}

@end

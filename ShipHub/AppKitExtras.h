//
//  AppKitExtras.h
//  Ship
//
//  Created by James Howard on 9/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSTextView (Extras)

- (CGFloat)heightForWidth:(CGFloat)width;

@end

@interface NSText (Extras)

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

@end

@interface NSEvent (Extras)

- (BOOL)isArrowDown;
- (BOOL)isArrowUp;
- (BOOL)isArrowLeft;
- (BOOL)isArrowRight;
- (BOOL)isPageUp;
- (BOOL)isPageDown;
- (BOOL)isPageHome;
- (BOOL)isPageEnd;
- (BOOL)isTabKey;
- (BOOL)isShiftTab;
- (BOOL)isSpace;
- (BOOL)isDelete;

- (BOOL)isReturn;

- (BOOL)modifierFlagsAreExclusively:(NSEventModifierFlags)flags;

@end

@interface NSScrollView (Extras)

- (void)scrollLineUp:(id)sender;
- (void)scrollLineDown:(id)sender;

- (void)scrollPageUp:(id)sender;
- (void)scrollPageDown:(id)sender;

- (void)scrollToEndOfDocument:(id)sender;
- (void)scrollToBeginningOfDocument:(id)sender;

@end

@interface NSView (Extras)

- (BOOL)isFirstResponder;

- (NSArray *)disableAllControls; // recursively disables all controls in all subviews that are not already disabled, and returns them

- (void)setContentView:(NSView *)subview;

- (void)enumerateChildViewsOfClass:(Class)type handler:(void (^)(id view, BOOL *stop))handler;

@end

@interface NSToolbar (Extras)

- (id)itemWithIdentifier:(NSString *)identifier;

@end

@interface NSPopUpButton (Extras)

- (void)selectItemMatchingPredicate:(NSPredicate *)predicate;

@end

@interface BaselineAdjustableTextAttachmentCell : NSTextAttachmentCell

- (void)setCellBaselineOffset:(NSPoint)p;

@end

#define NSTextAlignmentLeft NSLeftTextAlignment
#define NSTextAlignmentCenter NSCenterTextAlignment
#define NSTextAlignmentRight NSRightTextAlignment
#define NSTextAlignmentJustified NSJustifiedTextAlignment
#define NSTextAlignmentNatural NSNaturalTextAlignment

@interface KeyboardNavigablePopupButton : NSPopUpButton

@end

@interface NSPasteboard (Extras)

// Write a URL with the default string representation
- (void)writeURL:(NSURL *)URL;
// Write a URL with a customized string representation.
- (void)writeURL:(NSURL *)URL string:(NSString *)string;

@end

@interface TiledImageView : NSView

@property (nonatomic, strong) IBOutlet NSImage *image;

@end

@interface NSImage (Extras)

- (void)constrainToMaxEdge:(CGFloat)maxEdge;
- (NSImage *)imageConstrainedToMaxEdge:(CGFloat)maxEdge;
- (NSImage *)renderWithColor:(NSColor *)color;

- (BOOL)isHiDPI;

@end

@interface NSColor (Extras)

+ (NSColor *)extras_controlBlue;
+ (NSColor *)extras_outlineGray;
+ (NSColor *)extras_tableSeparator;

+ (NSColor *)ra_orange;
+ (NSColor *)ra_beige;
+ (NSColor *)ra_teal;
+ (NSColor *)ra_slate;

+ (NSColor *)colorWithHexString:(NSString *)hexString;

- (NSString *)hexString;

- (BOOL)isDark; // returns YES if color is closer to black than to white

- (NSColor *)colorByAdjustingBrightness:(CGFloat)amount; // amount < 1.0, color gets darker, amount > 1.0, color gets brighter

@end

@interface UndoManagerTextView : NSTextView

@property (readwrite, strong) NSUndoManager *undoManager;

@end

@interface NSFont (Extras)

+ (NSFont *)italicSystemFontOfSize:(CGFloat)fontSize;

@end


@interface NSButton (Extras)

- (void)setTextColor:(NSColor *)color;

@end

@interface MultiRepresentationPasteboardData : NSObject <NSPasteboardWriting>

+ (id<NSPasteboardWriting>)representationWithArray:(NSArray<id<NSPasteboardWriting>> *)array;

@end


@interface NSString (AppKitExtras)

- (void)drawWithTruncationInRect:(NSRect)rect attributes:(NSDictionary *)attrs;

@end

@interface NSAttributedString (AppKitExtras)

- (void)drawWithTruncationInRect:(NSRect)rect;

@end

@interface NSSplitView (AppKitExtras)

- (void)setPosition:(CGFloat)position ofDividerAtIndex:(NSInteger)idx animated:(BOOL)animate;

@end

@interface NSMenu (AppKitExtras)

- (void)walkMenuItems:(void (^)(NSMenuItem *m, BOOL *stop))visitor;

@end

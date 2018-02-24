//
//  LabelsControl.m
//  ShipHub
//
//  Created by James Howard on 5/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "LabelsControl.h"

#import "Extras.h"
#import "Label.h"
#import "GHEmoji.h"

@interface LabelsControlCell : NSCell

@end

@implementation LabelsControlCell

- (NSCellHitResult)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView {
    NSEventType type = event.type;
    switch (type) {
        case NSEventTypeMouseMoved:
        case NSEventTypeMouseExited:
        case NSEventTypeMouseEntered:
            return NSCellHitContentArea | NSCellHitTrackableArea;
        default: return NSCellHitNone;
            
    }
}

@end

@implementation LabelsControl

- (BOOL)acceptsFirstResponder { return NO; }
- (BOOL)canBecomeKeyView { return NO; }

+ (Class)cellClass { return [LabelsControlCell class]; }

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        self.allowsExpansionToolTips = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(emojiDidUpdate:) name:GHEmojiDidUpdateNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)emojiDidUpdate:(NSNotification *)note {
    NSString *emojiName = [note.userInfo objectForKey:GHEmojiUpdatedKey];
    for (Label *l in _labels) {
        if ([l.name containsString:emojiName]) {
            [self setNeedsDisplay:YES];
            break;
        }
    }
}

- (void)setLabels:(NSArray<Label *> *)labels {
    _labels = labels;
    [self setNeedsDisplay:YES];
}

- (CGSize)fittingSize {
    return [[self class] sizeLabels:_labels];
}

static const CGFloat corner = 3.0;
static const CGFloat hMarg = 4.0;
static const CGFloat vMarg = 1.0;
static const CGFloat fontSize = 11.0;
static const CGFloat spacing = 6.0;
static const CGFloat height = 16.0;
static const CGFloat radius = 7.0;
static const CGFloat border = 1.0;

+ (CGSize)sizeLabels:(NSArray<Label *> *)labels {
    NSDictionary *strAttrs = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize:fontSize] };
    
    CGFloat width = 0.0;
    NSUInteger i = 0;
    for (Label *l in labels) {
        if (i != 0) {
            width += spacing;
        }
        width += hMarg * 2.0;
        width += [l.name sizeWithAttributes:strAttrs].width;
        i++;
    }

    return CGSizeMake(ceil(width), height);
}

+ (void)drawLabels:(NSArray<Label *> *)labels
            inRect:(CGRect)b
       highlighted:(BOOL)highlighted
   backgroundColor:(NSColor *)backgroundColor
{
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    CGContextTranslateCTM(ctx, b.origin.x, b.origin.y);
    b.origin = CGPointZero;
    
    if (labels.count == 0) {
        CGContextRestoreGState(ctx);
        return;
    }
    
    CGContextClipToRect(ctx, b);
    
    [[NSColor blackColor] set];
    
    NSDictionary *strAttrs = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize:fontSize] };
    
    NSMutableArray *sizes = [NSMutableArray new];
    
    NSArray *attrStrs = [labels arrayByMappingObjects:^id(Label *l) {
        NSMutableAttributedString *attrStr = [[l emojifiedName] mutableCopy];
        NSMutableDictionary *attrs = [strAttrs mutableCopy];
        attrs[NSForegroundColorAttributeName] = [l.color isDark] ? [NSColor whiteColor] : [NSColor blackColor];
        [attrStr addAttributes:attrs range:NSMakeRange(0, attrStr.length)];
        return attrStr;
    }];
    
    // size forward
    NSInteger i = 0;
    CGFloat w = 0.0;
    for (; i < labels.count; i++) {
        if (i != 0) {
            w += spacing;
        }
        NSAttributedString *l = attrStrs[i];
        CGFloat lw = [l size].width;
        [sizes addObject:@(lw)];
        w += hMarg * 2.0;
        w += lw;
    }
    // size backwards until we do fit (or have to draw all circles and possibly clip)
    NSInteger numCircles = 0;
    while (i > 0 && w > CGRectGetWidth(b)) {
        i--;
        w -= spacing;
        CGFloat lw = [sizes[i] doubleValue];
        w -= lw;
        w -= hMarg * 2.0;
        numCircles++;
        if (numCircles == 1) {
            w += spacing + radius * 2.0 + border * 2.0;
        } else {
            w += radius;
        }
    }
    
    // draw full labels up to i, then draw circles up to labels.count
    CGFloat xOff = 0.0;
    CGFloat yOff = 0.0;
    
    for (NSInteger j = 0; j < i; j++) {
        if (j != 0) {
            xOff += spacing;
        }
        Label *l = labels[j];
        NSAttributedString *attrStr = attrStrs[j];
        CGFloat lw = [sizes[j] doubleValue];
        CGRect r = CGRectMake(xOff, yOff, lw + hMarg * 2.0, height - (yOff * 2.0));
        
        // draw the label full width
        NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:r xRadius:corner yRadius:corner];
        
        [[l color] setFill];
        [path fill];
        
        CGRect drawRect = r;
        drawRect.origin.x += hMarg;
        drawRect.origin.y += vMarg;
        drawRect.size.width -= hMarg * 2.0;
        drawRect.size.height -= vMarg * 2.0;
        [attrStr drawInRect:drawRect];
        
        xOff += r.size.width;
    }
    
    // draw circles
    yOff = 1.0;
    xOff += round(radius * (labels.count-i));
    CGContextSetLineWidth(ctx, border);
    if (highlighted) {
        [[NSColor whiteColor] setStroke];
    }
    NSColor *background = backgroundColor;
    for (NSInteger j = labels.count; j > i; j--) {
        Label *l = labels[j-1];
        // draw background knockout
        [background setFill];
        CGContextSetBlendMode(ctx, kCGBlendModeCopy);
        CGContextAddEllipseInRect(ctx, CGRectMake(xOff, yOff, radius * 2.0, radius * 2.0));
        CGContextDrawPath(ctx, kCGPathFill);
        
        CGContextSetBlendMode(ctx, kCGBlendModeNormal);
        if (!highlighted) {
            [[[l color] colorByAdjustingBrightness:0.85] setStroke];
        } else {
            [[NSColor whiteColor] setStroke];
        }
        
        CGContextAddEllipseInRect(ctx, CGRectMake(xOff + 1.5, yOff + 1.5, radius * 2.0 - 3.0, radius * 2.0 - 3.0));
        [[l color] setFill];
        CGContextDrawPath(ctx, kCGPathFillStroke);
        
        xOff -= radius;
    }
    
    CGContextRestoreGState(ctx);
}

- (void)drawRect:(NSRect)dirtyRect {
    CGRect b = self.bounds;
    [[self class] drawLabels:_labels inRect:b highlighted:self.highlighted backgroundColor:[NSColor clearColor]];
}

- (CGRect)expansionFrameWithFrame:(NSRect)contentFrame {
    CGSize size = [LabelsControl sizeLabels:_labels];
    if (size.width > contentFrame.size.width) {
        contentFrame.size = size;
        return contentFrame;
    } else {
        return CGRectZero; // empty means no expansion needed
    }
}

- (void)drawWithExpansionFrame:(NSRect)contentFrame inView:(NSView *)view
{
    [[self class] drawLabels:_labels inRect:contentFrame highlighted:NO backgroundColor:[NSColor clearColor]];
}

@end

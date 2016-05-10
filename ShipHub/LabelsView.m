//
//  LabelsView.m
//  ShipHub
//
//  Created by James Howard on 5/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "LabelsView.h"

#import "Extras.h"
#import "Label.h"

@implementation LabelsView

- (void)setLabels:(NSArray<Label *> *)labels {
    _labels = labels;
    [self setNeedsDisplay:YES];
}

- (void)setHighlighted:(BOOL)highlighted {
    _highlighted = highlighted;
    [self setNeedsDisplay:YES];
}

- (CGSize)fittingSize {
    return [[self stringContents] size];
}

- (NSMutableAttributedString *)stringContents {
    NSMutableAttributedString *str = [NSMutableAttributedString new];
    
    NSInteger i = 0;
    NSInteger c = _labels.count;
    for (Label *l in _labels) {
        i++;
        [str appendAttributes:@{NSForegroundColorAttributeName:[l color],
                                NSFontAttributeName: [NSFont systemFontOfSize:13.0]}
                       format:@"%@%s", l.name, (i == c ? "" : ", ")];
    }
    
    return str;
}

+ (void)drawLabels:(NSArray<Label *> *)labels inRect:(CGRect)b highlighted:(BOOL)highlighted {
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    
    [[NSColor clearColor] set];
    NSRectFill(b);
    
    if (labels.count == 0) {
        CGContextRestoreGState(ctx);
        return;
    }
    
    [[NSColor blackColor] set];
    
    const CGFloat corner = 3.0;
    const CGFloat hMarg = 4.0;
    const CGFloat vMarg = 1.0;
    const CGFloat fontSize = 13.0;
    const CGFloat spacing = 6.0;
    const CGFloat height = 20.0;
    
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
    
    
    if (width > CGRectGetWidth(b)) {
        // compact drawing
        const CGFloat radius = 7.0;
        const CGFloat border = 1.0;
        
        CGContextSetLineWidth(ctx, border);
        
        CGFloat xOff = radius * (labels.count - 1);
        CGFloat yOff = 1.0;
        
        
        if (highlighted) {
            [[NSColor whiteColor] setStroke];
        }
        
        
        
        for (Label *l in labels.reverseObjectEnumerator) {
            
            // draw background knockout
            [[NSColor clearColor] setFill];
            CGContextSetBlendMode(ctx, kCGBlendModeCopy);
            CGContextAddEllipseInRect(ctx, CGRectMake(xOff, yOff, radius * 2.0, radius * 2.0));
            CGContextDrawPath(ctx, kCGPathFill);
            
            CGContextSetBlendMode(ctx, kCGBlendModeNormal);
            if (!highlighted) {
                [[[l color] colorByAdjustingBrightness:0.8] setStroke];
            } else {
                [[NSColor whiteColor] setStroke];
            }
            
            CGContextAddEllipseInRect(ctx, CGRectMake(xOff + 1.5, yOff + 1.5, radius * 2.0 - 3.0, radius * 2.0 - 3.0));
            [[l color] setFill];
            CGContextDrawPath(ctx, kCGPathFillStroke);
            
            xOff -= radius;
        }
    } else {
        // normal drawing
        
        CGFloat xOff = 0.0;
        CGFloat yOff = 0.0;
        for (Label *l in labels) {
            CGFloat lw = [l.name sizeWithAttributes:strAttrs].width;
            CGRect r = CGRectMake(xOff, yOff, lw + hMarg * 2.0, height - (yOff * 2.0));
            NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:r xRadius:corner yRadius:corner];
            
            [[l color] setFill];
            [path fill];
            
            NSMutableDictionary *attrs = [strAttrs mutableCopy];
            attrs[NSForegroundColorAttributeName] = [l.color isDark] ? [NSColor whiteColor] : [NSColor blackColor];
            
            CGRect drawRect = r;
            drawRect.origin.x += hMarg;
            drawRect.origin.y += vMarg;
            drawRect.size.width -= hMarg * 2.0;
            drawRect.size.height -= vMarg * 2.0;
            [l.name drawInRect:drawRect withAttributes:attrs];
            
            xOff += r.size.width + spacing;
        }
    }
    
    CGContextRestoreGState(ctx);
}

- (void)drawRect:(NSRect)dirtyRect {
    CGRect b = self.bounds;
    [[self class] drawLabels:_labels inRect:b highlighted:_highlighted];
}

@end

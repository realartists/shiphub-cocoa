//
//  EmptyLabelView.m
//  ShipHub
//
//  Created by James Howard on 9/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "EmptyLabelView.h"

#import "Extras.h"

@interface EmptyLabelView ()

@property NSAttributedString *attrStr;

@end

@implementation EmptyLabelView

- (void)setStringValue:(NSString *)stringValue {
    _attrStr = nil;
    _stringValue = [stringValue copy];
    [self setNeedsDisplay:YES];
}

- (void)setFont:(NSFont *)font {
    _attrStr = nil;
    _font = font;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    // Manually drawing the text here to work around missing NSTextField.maximumNumberOfLines = 0 on 10.10.
    
    if (!_stringValue) return;
    if (!_attrStr) {
        NSString *text = _stringValue ?: @"";
        NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
        para.alignment = NSTextAlignmentCenter;
        NSDictionary *attrs = @{ NSFontAttributeName : _font ?: [NSFont boldSystemFontOfSize:16.0],
                                 NSParagraphStyleAttributeName : para,
                                 NSForegroundColorAttributeName : [NSColor tertiaryLabelColor] };
        _attrStr = [[NSAttributedString alloc] initWithString:text attributes:attrs];

    }
    
    CGRect b = self.bounds;
    CGSize s = b.size;
    s.width -= 20.0;
    
    s.width = MIN(s.width, 300.0);
    
    s = [_attrStr multilineSizeThatFitsInSize:s];
    CGRect r = CGRectZero;
    r.size = s;
    
    r = CenteredRectInRect(b, r);
    
    [_attrStr drawInRect:r];
}

@end

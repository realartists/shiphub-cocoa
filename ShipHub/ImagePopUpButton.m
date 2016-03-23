//
//  ImagePopUpButton.m
//  Ship
//
//  Created by James Howard on 12/16/15.
//  Copyright © 2015 Real Artists, Inc. All rights reserved.
//

#import "ImagePopUpButton.h"
#import "AppKitExtras.h"

@implementation ImagePopUpButton {
    NSImage *_normalImage;
    NSImage *_highlightImage;
}

- (void)setBackgroundImage:(NSImage *)backgroundImage {
    _backgroundImage = backgroundImage;
    _normalImage = [_backgroundImage renderWithColor:[NSColor grayColor]];
    _highlightImage = [_backgroundImage renderWithColor:[NSColor darkGrayColor]];
    [self setNeedsDisplay];
}

- (void)drawRect:(NSRect)dirtyRect {
#if 0
    [[NSColor greenColor] set];
    NSRectFill(self.bounds);
#endif
    
    NSImage *image = nil;
    
    if (self.highlighted) {
        image = _highlightImage;
    } else {
        image = _normalImage;
    }
    
    [image drawInRect:self.bounds];
}

@end

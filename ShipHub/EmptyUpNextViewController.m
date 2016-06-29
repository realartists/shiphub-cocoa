//
//  EmptyUpNextViewController.m
//  ShipHub
//
//  Created by James Howard on 7/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "EmptyUpNextViewController.h"

#import "Extras.h"

@interface EmptyUpNextView : NSView

@end

@interface EmptyUpNextViewController ()

@end

@implementation EmptyUpNextViewController

- (void)loadView {
    self.view = [EmptyUpNextView new];
}

@end

@implementation EmptyUpNextView

- (void)drawRect:(NSRect)dirtyRect {
    // Manually drawing the text here to work around missing NSTextField.maximumNumberOfLines = 0 on 10.10.
    static dispatch_once_t onceToken;
    static NSAttributedString *str;
    dispatch_once(&onceToken, ^{
        NSString *text = NSLocalizedString(@"To add Issues to your Up Next queue, drag them here or use the Add to Up Next menu item", nil);
        NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
        para.alignment = NSTextAlignmentCenter;
        NSDictionary *attrs = @{ NSFontAttributeName : [NSFont boldSystemFontOfSize:16.0],
                                 NSParagraphStyleAttributeName : para,
                                 NSForegroundColorAttributeName : [NSColor tertiaryLabelColor] };
        str = [[NSAttributedString alloc] initWithString:text attributes:attrs];
    });
    
    CGRect b = self.bounds;
    CGSize s = b.size;
    s.width -= 20.0;
    
    s.width = MIN(s.width, 300.0);
    
    s = [str multilineSizeThatFitsInSize:s];
    CGRect r = CGRectZero;
    r.size = s;
    
    r = CenteredRectInRect(b, r);
    
    [str drawInRect:r];
}

@end

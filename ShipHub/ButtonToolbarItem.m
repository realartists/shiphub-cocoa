//
//  ButtonToolbarItem.m
//  Ship
//
//  Created by James Howard on 6/23/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "ButtonToolbarItem.h"

#import "Extras.h"

@interface ButtonSegmentedControl : NSSegmentedControl

@property (nonatomic) BOOL hidesDuringSheet;

@end

@interface ButtonToolbarBadgeView : NSView

@property (nonatomic, copy) NSString *badgeString;

@end

@interface ButtonToolbarItem ()

@property (strong) ButtonSegmentedControl *segmented;
@property (strong) ButtonToolbarBadgeView *badgeView;

@end

@implementation ButtonToolbarItem

- (void)configureView {
    CGSize size = CGSizeMake(36, 23);     // Same as Mail uses for its toolbar buttons.
    _segmented  = [[ButtonSegmentedControl alloc] initWithFrame:(CGRect){ .origin = CGPointZero, .size = size }];
    _segmented.segmentCount = 1;
    [_segmented setWidth:size.width forSegment:0];
    [_segmented.cell setTrackingMode:NSSegmentSwitchTrackingMomentary];
    
    CGSize overallSize = size;
    overallSize.width += 10.0;
    overallSize.height += 2.0;
    self.minSize = overallSize;
    self.maxSize = overallSize;
    self.view = _segmented;
}

- (void)setButtonImage:(NSImage *)image {
    [_segmented setImage:image forSegment:0];
}

- (NSImage *)buttonImage {
    return [_segmented imageForSegment:0];
}

- (void)setTrackingMode:(NSSegmentSwitchTracking)trackingMode {
    [_segmented.cell setTrackingMode:trackingMode];
}

- (NSSegmentSwitchTracking)trackingMode {
    return [_segmented.cell trackingMode];
}

- (BOOL)isOn {
    return [_segmented isSelectedForSegment:0];
}

- (void)setOn:(BOOL)on {
    [_segmented setSelected:on forSegment:0];
}

- (void)setHidesDuringSheet:(BOOL)hidesDuringSheet {
    _segmented.hidesDuringSheet = hidesDuringSheet;
}

- (BOOL)hidesDuringSheet {
    return _segmented.hidesDuringSheet;
}

- (void)setEnabled:(BOOL)enabled {
    [super setEnabled:enabled];
    if (_grayWhenDisabled) {
        [_segmented setEnabled:enabled];
    } else {
        _segmented.animator.hidden = !enabled;
    }
}

- (void)setBadgeString:(NSString *)badgeString {
    if (!_badgeView) {
        if (!badgeString.length) return;
        
        _badgeView = [ButtonToolbarBadgeView new];
        [_segmented addSubview:_badgeView];
    }
    
    _badgeView.badgeString = badgeString;
    
    CGSize size = [_badgeView fittingSize];
    _badgeView.frame = CGRectMake(_segmented.bounds.size.width - size.width - 3.0,
                                  0.0,
                                  size.width, size.height);
    
    _badgeView.hidden = badgeString.length == 0;
}

- (NSString *)badgeString {
    return _badgeView.badgeString;
}

@end

@implementation ButtonToolbarBadgeView

- (id)init {
    if (self = [super init]) {
        self.wantsLayer = YES;
        //self.layer.shadowOpacity = 0.5;
    }
    return self;
}

static NSDictionary *textAttrs() {
    static dispatch_once_t onceToken;
    static NSDictionary *attrs;
    dispatch_once(&onceToken, ^{
        attrs = @{ NSFontAttributeName : [NSFont systemFontOfSize:8.0],
                   NSForegroundColorAttributeName : [NSColor whiteColor] };
    });
    return attrs;
}

static CGFloat cornerRadius = 6.0;

- (CGSize)fittingSize {
    CGSize textSize = [_badgeString sizeWithAttributes:textAttrs()];
    if (textSize.width < cornerRadius * 2.0) {
        return CGSizeMake(cornerRadius * 2.0, cornerRadius * 2.0);
    } else {
        return CGSizeMake(textSize.width + cornerRadius, cornerRadius * 2.0);
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    CGRect bounds = self.bounds;
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:cornerRadius yRadius:cornerRadius];
    [[NSColor redColor] setFill];
    [path fill];
    
    CGSize textSize = [_badgeString sizeWithAttributes:textAttrs()];
    CGRect textRect = CenteredRectInRectWithoutRounding(bounds, CGRectMake(0, 0, textSize.width, textSize.height));
    textRect.origin.y += 0.5;
    
    [[NSColor whiteColor] set];
    [_badgeString drawInRect:textRect withAttributes:textAttrs()];
}

- (void)setBadgeString:(NSString *)badgeString {
    if (![_badgeString isEqualToString:badgeString]) {
        _badgeString = [badgeString copy];
        [self setNeedsDisplay:YES];
    }
}

@end

@implementation ButtonSegmentedControl {
    BOOL _hidingDuringSheet;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    [super viewWillMoveToWindow:newWindow];
    NSWindow *oldWindow = self.window;
    if (oldWindow) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillBeginSheetNotification object:oldWindow];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidEndSheetNotification object:oldWindow];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willBeginSheet:) name:NSWindowWillBeginSheetNotification object:newWindow];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEndSheet:) name:NSWindowDidEndSheetNotification object:newWindow];
}

- (void)willBeginSheet:(NSNotification *)note {
    if (_hidesDuringSheet && !_hidingDuringSheet) {
        _hidingDuringSheet = YES;
        self.animator.hidden = YES;
    }
}

- (void)didEndSheet:(NSNotification *)note {
    if (_hidingDuringSheet) {
        _hidingDuringSheet = NO;
        self.animator.hidden = NO;
    }
}

@end

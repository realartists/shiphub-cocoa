//
//  CompactIssueCellViewController.m
//  ShipHub
//
//  Created by James Howard on 5/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "CompactIssueCellViewController.h"

#import "Extras.h"
#import "Issue.h"
#import "LabelsControl.h"
#import "Label.h"
#import "Milestone.h"
#import "Repo.h"
#import "Account.h"

@interface CompactIssueRowView ()

@property (nonatomic, strong) Issue *issue;
@property (nonatomic, assign) CompactIssueDateType dateType;

@property (weak) CompactIssueCellViewController *controller;

@end

@interface CompactIssueCellViewController ()

@end

@implementation CompactIssueCellViewController

+ (CGFloat)cellHeightForIssue:(Issue *)issue {
    if (issue.labels.count == 0) return 92.0;
    return 92.0 + 16.0 + 2.0;
}

- (void)loadView {
    CompactIssueRowView *row = [[CompactIssueRowView alloc] initWithFrame:CGRectMake(0, 0, 300, 92.0)];
    self.view = row;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CompactIssueRowView *view = (id)self.view;
    view.issue = _issue;
    view.controller = self;
}

- (void)setIssue:(Issue *)issue {
    _issue = issue;
    CompactIssueRowView *row = (id)self.view;
    row.issue = _issue;
}

- (void)prepareForReuse {
    CompactIssueRowView *row = (id)self.view;
    row.issue = nil;
    row.emphasized = NO;
    row.selected = NO;
    row.nextRowSelected = NO;
}

- (void)setDateType:(CompactIssueDateType)dateType {
    _dateType = dateType;
    CompactIssueRowView *row = (id)self.view;
    row.dateType = dateType;
}

@end

@interface CompactIssueRowView () {
    CGRect _dateTTRect;
    NSToolTipTag _dateTTT;
    NSString *_dateTT;
    LabelsControl *_labelsControl;
}

@end

@implementation CompactIssueRowView

- (id)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        _labelsControl = [LabelsControl new];
        [self addSubview:_labelsControl];
    }
    return self;
}

- (BOOL)autoresizesSubviews {
    return NO;
}

- (void)layout {
    [super layout];
    CGRect b = self.bounds;
    _labelsControl.frame = CGRectMake(marginLeft, marginBottom, CGRectGetWidth(b) - marginLeft - marginRight, 16.0);
    _labelsControl.hidden = _issue.labels.count == 0;
}

-  (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    [self setNeedsLayout:YES];
}

- (BOOL)isFlipped {
    return NO;
}

- (void)updateLabelsHighlight {
    _labelsControl.highlighted = self.emphasized && self.selected;
}

- (void)setEmphasized:(BOOL)emphasized {
    [super setEmphasized:emphasized];
    [self updateLabelsHighlight];
    [self setNeedsDisplay:YES];
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self updateLabelsHighlight];
    [self setNeedsDisplay:YES];
}

- (void)setNextRowSelected:(BOOL)nextRowSelected {
    [super setNextRowSelected:nextRowSelected];
    [self setNeedsDisplay:YES];
}

- (void)setIssue:(Issue *)issue {
    _issue = issue;
    _labelsControl.labels = issue.labels;
    [self setNeedsDisplay:YES];
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(nullable void *)data {
    return _dateTT ?: @"";
}

static const CGFloat marginRight = 8.0;
static const CGFloat marginLeft = 20.0;
static const CGFloat marginTop = 8.0;
static const CGFloat marginBottom = 7.0;

- (void)drawBackgroundInRect:(NSRect)dirtyRect {
    [super drawBackgroundInRect:dirtyRect];
    
    NSColor *background = [NSColor whiteColor];
    if (self.selected) {
        if (self.emphasized) {
            background = [NSColor alternateSelectedControlColor];
        } else {
            background = [NSColor secondarySelectedControlColor];
        }
    }
    [background setFill];
    
    CGRect gap = CGRectMake(0, CGRectGetHeight(self.bounds) - 1.0, self.bounds.size.width, 1.0);
    NSRectFill(gap);
}

- (void)drawSeparatorInRect:(NSRect)dirtyRect {
    
    CGRect r = CGRectMake(0.0, 0.0, self.bounds.size.width, 1.0);
    if (self.selected || self.isNextRowSelected) {
        [[NSColor whiteColor] set];
    } else {
        [[NSColor extras_tableSeparator] set];
        r.origin.x += marginLeft;
        r.size.width -= marginLeft;
    }
    
    NSRectFill(r);
}

- (NSMenu *)menuForEvent:(NSEvent *)event {
    return [[self superview] menuForEvent:event];
}

- (void)drawRect:(NSRect)dirtyRect {
    BOOL emph = self.emphasized && self.selected;
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] CGContext];
    CGContextSaveGState(ctx);
    [super drawRect:dirtyRect];
    CGContextRestoreGState(ctx);
    
    CGRect b = self.bounds;
    
    CGFloat bodyBottom = _issue.labels.count > 0 ? marginBottom + 18.0 : marginBottom;
    
    CGContextSaveGState(ctx);
    
    // Draw the # at the upper right
    NSDictionary *sharedAttrs =
    @{ NSFontAttributeName : [NSFont systemFontOfSize:11.0 weight:NSFontWeightSemibold],
       NSForegroundColorAttributeName : emph ? [NSColor whiteColor] : [NSColor darkGrayColor] };
    
    NSDictionary *numAttrs = sharedAttrs;
    if (_issue.closed) {
        numAttrs = [numAttrs dictionaryByAddingEntriesFromDictionary:@{ NSStrikethroughStyleAttributeName : @YES }];
    }
    
    NSString *numStr = [NSString stringWithFormat:@"#%@", _issue.number];
    
    NSMutableAttributedString *numAttrStr = [NSMutableAttributedString new];
    
    if (_issue.pullRequest) {
        NSDictionary *prAttrs = [sharedAttrs dictionaryByAddingEntriesFromDictionary:@{ NSFontAttributeName: [NSFont systemFontOfSize:11.0 weight:NSFontWeightBold] }];
        [numAttrStr appendAttributes:prAttrs format:@"PR "];
    }
    
    [numAttrStr appendAttributedString:[[NSAttributedString alloc] initWithString:numStr attributes:numAttrs]];
    
    CGSize numSize = [numAttrStr size];
    
    CGRect numRect = CGRectMake(CGRectGetMaxX(b) - numSize.width - marginRight,
                                CGRectGetMaxY(b) - numSize.height - marginTop - 2.0,
                                numSize.width,
                                numSize.height);
    
    [numAttrStr drawInRect:numRect];
    
    // Draw the date just under the number
    NSDate *date = nil;
    switch (_dateType) {
        case CompactIssueDateTypeCreatedAt:
            date = _issue.createdAt;
            break;
        case CompactIssueDateTypeUpdatedAt:
            date = _issue.updatedAt ?: _issue.createdAt;
            break;
        case CompactIssueDateTypeClosedAt:
            date = _issue.closedAt ?: _issue.updatedAt ?: _issue.createdAt;
            break;
    }
    
    NSDictionary *dateAttrs =
    @{ NSFontAttributeName : [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular],
       NSForegroundColorAttributeName : sharedAttrs[NSForegroundColorAttributeName] };
    NSString *dateStr = [[NSDateFormatter shortRelativeDateFormatter] stringFromDate:date];
    CGSize dateSize = [dateStr sizeWithAttributes:dateAttrs];
    CGRect dateRect = CGRectMake(CGRectGetMaxX(b) - dateSize.width - marginRight,
                                 CGRectGetMinY(numRect) - 2.0 - dateSize.height,
                                 dateSize.width,
                                 dateSize.height);
    [dateStr drawInRect:dateRect withAttributes:dateAttrs];
    
    if (_issue.closed && _issue.closedAt) {
        if ([_issue.updatedAt isEqual:_issue.closedAt]) {
            _dateTT = [NSString stringWithFormat:NSLocalizedString(@"Created %@\nClosed %@", nil), [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:_issue.createdAt], [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:_issue.closedAt]];
        } else {
            _dateTT = [NSString stringWithFormat:NSLocalizedString(@"Created %@\nClosed %@\nModified %@", nil), [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:_issue.createdAt], [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:_issue.closedAt], [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:_issue.updatedAt]];
        }
    } else if (_issue.updatedAt && ![_issue.updatedAt isEqual:_issue.createdAt]) {
        _dateTT = [NSString stringWithFormat:NSLocalizedString(@"Created %@\nModified %@", nil), [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:_issue.createdAt], [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:_issue.updatedAt]];
    } else {
        _dateTT = [NSString stringWithFormat:NSLocalizedString(@"Created %@", nil), [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:_issue.createdAt]];
    }
    
    if (_dateTTT == 0 || !CGRectEqualToRect(dateRect, _dateTTRect)) {
        if (_dateTTT != 0) {
            [self removeToolTip:_dateTTT];
        }
        _dateTTRect = dateRect;
        _dateTTT = [self addToolTipRect:dateRect owner:self userData:NULL];
    }
    
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity); // needed after using -drawInRect:withAttributes: and before using CoreText
    
    // Draw the title using 1 or 2 lines starting at the upper left and wrapping around number and date
    
    NSDictionary *titleAttrs = @{ NSFontAttributeName : [NSFont boldSystemFontOfSize:13.0],
                                  NSForegroundColorAttributeName : emph ? [NSColor whiteColor] : [NSColor blackColor] };
    NSAttributedString *titleStr = [[NSAttributedString alloc] initWithString:_issue.title attributes:titleAttrs];
    
    CGRect titleBoundingRect = CGRectMake(marginLeft,
                                          CGRectGetMaxY(b) - marginTop - 34.0,
                                          CGRectGetWidth(b) - marginLeft - marginRight,
                                          34.0);
    
    CGPathRef titleBoundsPath = CGPathCreateWithRect(titleBoundingRect, NULL);
    CGPathRef numExclusionPath = CGPathCreateWithRect(CGRectInset(numRect, -4.0, 0.0), NULL);
    CGPathRef dateExclusionPath = CGPathCreateWithRect(CGRectInset(dateRect, -4.0, 0.0), NULL);
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)titleStr);
    NSDictionary *frameAttrs = @{ (__bridge id)kCTFrameClippingPathsAttributeName : @[(__bridge id)numExclusionPath, (__bridge id)dateExclusionPath] };
    CFRelease(numExclusionPath);
    CFRelease(dateExclusionPath);
    
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, titleStr.length), titleBoundsPath, (__bridge CFDictionaryRef)frameAttrs);
    CFRelease(titleBoundsPath);
    
    CFArrayRef lines = CTFrameGetLines(frame);
    NSUInteger lineCount = CFArrayGetCount(lines);
    for (NSUInteger i = 0; i < MIN(lineCount, 2); i++) {
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGPoint origin = CGPointZero;
        CTFrameGetLineOrigins(frame, CFRangeMake(i, 1), &origin);
        origin.x += titleBoundingRect.origin.x;
        origin.y += titleBoundingRect.origin.y;
        CGContextSetTextPosition(ctx, origin.x, origin.y);
        CFRange lineRange = CTLineGetStringRange(line);
        
        if (i == 1 && lineRange.location + lineRange.length < titleStr.length) {
            NSAttributedString *ellipsis = [[NSAttributedString alloc] initWithString:@"…" attributes:titleAttrs];
            CTLineRef truncChar = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)ellipsis);
            NSAttributedString *lastStr = [titleStr attributedSubstringFromRange:NSMakeRange(lineRange.location, titleStr.length-lineRange.location)];
            CTLineRef fullLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)lastStr);
            CTLineRef trunc = CTLineCreateTruncatedLine(fullLine, titleBoundingRect.size.width - dateRect.size.width, kCTLineTruncationEnd, truncChar);
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
    
    // Draw the repository
    NSDictionary *repoAttrs = sharedAttrs;
    NSString *repoStr = _issue.repository.fullName;
    CGSize repoSize = [repoStr sizeWithAttributes:repoAttrs];
    CGRect repoRect;
    if (lineCount == 1) {
        repoRect = CGRectMake(marginLeft,
                              dateRect.origin.y,
                              CGRectGetWidth(b) - marginLeft - marginRight - CGRectGetWidth(dateRect) - 4.0,
                              repoSize.height);
    } else {
        repoRect = CGRectMake(marginLeft,
                              CGRectGetMinY(titleBoundingRect) - repoSize.height,
                              CGRectGetWidth(b) - marginLeft - marginRight,
                              repoSize.height);
    }
    
    [repoStr drawWithTruncationInRect:repoRect attributes:repoAttrs];
    
    // Draw the info line
    static NSImage *milestoneIcon = nil;
    static NSImage *milestoneSelIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSImage *milestoneBase = [NSImage imageNamed:@"563-calendar"];
        milestoneBase.size = CGSizeMake(10.0, 10.0);
        milestoneIcon = [milestoneBase renderWithColor:repoAttrs[NSForegroundColorAttributeName]];
        milestoneSelIcon = [milestoneBase renderWithColor:[NSColor whiteColor]];
    });
    
    NSDictionary *infoLabelAttrs = dateAttrs;
    NSDictionary *infoItemAttrs = @{ NSFontAttributeName : infoLabelAttrs[NSFontAttributeName],
                                     NSForegroundColorAttributeName : emph ? [NSColor whiteColor] : [NSColor blackColor] };
    NSMutableAttributedString *infoStr = [NSMutableAttributedString new];
    NSString *assignedTo = NSLocalizedString(@"Assigned to ", nil);
    NSRange assignedToRange = NSMakeRange(NSNotFound, 0);
    [infoStr appendAttributes:infoLabelAttrs format:NSLocalizedString(@"By ", nil)];
    [infoStr appendAttributes:infoItemAttrs format:@"%@", _issue.originator.login];
    if (_issue.assignees.count == 1) {
        Account *assignee = [_issue.assignees firstObject];
        [infoStr appendAttributes:infoLabelAttrs format:@" • "];
        assignedToRange.location = infoStr.length;
        assignedToRange.length = assignedTo.length;
        [infoStr appendAttributes:infoItemAttrs format:@"%@", assignedTo];
        [infoStr appendAttributes:infoItemAttrs format:@"%@", assignee.login];
    } else if (_issue.assignees.count > 1) {
        Account *assignee = [_issue.assignees firstObject];
        [infoStr appendAttributes:infoLabelAttrs format:@" • "];
        assignedToRange.location = infoStr.length;
        assignedToRange.length = assignedTo.length;
        [infoStr appendAttributes:infoItemAttrs format:@"%@", assignedTo];
        [infoStr appendAttributes:infoItemAttrs format:@"%@ +%tu", assignee.login, _issue.assignees.count-1];
    } else {
        // Not assigned
        [infoStr appendAttributes:infoLabelAttrs format:@" • "];
        [infoStr appendAttributes:infoItemAttrs format:NSLocalizedString(@"Unassigned", nil)];
    }
    if (_issue.milestone) {
        [infoStr appendAttributes:infoLabelAttrs format:@" • "];
        NSTextAttachment *attachment = [NSTextAttachment new];
        attachment.image = emph ? milestoneSelIcon : milestoneIcon;
        [infoStr appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
        [infoStr addAttributes:infoLabelAttrs range:NSMakeRange(infoStr.length-1, 1)];
        [infoStr addAttribute:NSBaselineOffsetAttributeName value:@(3.0) range:NSMakeRange(infoStr.length-1, 1)];
        [infoStr appendAttributes:infoItemAttrs format:@" %@", _issue.milestone.title];
    }
    
    CGSize infoSize = [infoStr size];
    if (infoSize.width > (CGRectGetWidth(b) - marginLeft - marginRight - 12.0) && _issue.assignees.count != 0) {
        // if it's too wide, see if we can abbreviate the assignee label a bit
        [infoStr replaceCharactersInRange:assignedToRange withString:@""];
        infoSize = [infoStr size];
    }
    
    CGRect infoRect = CGRectMake(marginLeft,
                                 CGRectGetMinY(repoRect) - infoSize.height - 2.0,
                                 CGRectGetWidth(b) - marginLeft - marginRight,
                                 infoSize.height + 1.0);
    [infoStr drawWithTruncationInRect:infoRect];
    
    // Draw as much of the issue body as we can.
    NSString *body = @"";
    NSDictionary *bodyAttrs = nil;
    if ([_issue.body length] == 0) {
        body = NSLocalizedString(@"No Description Given", nil);
        bodyAttrs = @{ NSFontAttributeName : [NSFont italicSystemFontOfSize:11.0],
                       NSForegroundColorAttributeName : infoLabelAttrs[NSForegroundColorAttributeName] };
    } else {
        body = [_issue.body stringByCollapsingNewlines];
        bodyAttrs = @{ NSFontAttributeName : [NSFont systemFontOfSize:11.0],
                       NSForegroundColorAttributeName : infoLabelAttrs[NSForegroundColorAttributeName] };
    }
    
    CGRect bodyRect = CGRectMake(marginLeft,
                                 bodyBottom,
                                 CGRectGetWidth(b) - marginLeft - marginRight,
                                 CGRectGetMinY(infoRect) - 1.0 - bodyBottom);
    [body drawWithTruncationInRect:bodyRect attributes:bodyAttrs];
    
    // Draw the unread indicator, if necessary
    if (_issue.unread) {
        const CGFloat radius = 5.0;
        CGRect unreadRect = CGRectMake(4.0, CGRectGetHeight(b) - marginTop - (2*radius) - 3.0, radius*2, radius*2);
        
        if (emph) {
            CGContextSetFillColorWithColor(ctx, [[NSColor whiteColor] CGColor]);
            [[NSColor whiteColor] setFill];
        } else {
            CGContextSetFillColorWithColor(ctx, [[NSColor extras_controlBlue] CGColor]);
        }
        
        CGContextAddEllipseInRect(ctx, unreadRect);
        CGContextDrawPath(ctx, kCGPathFill);
    }
    
    CGContextRestoreGState(ctx);
}

@end

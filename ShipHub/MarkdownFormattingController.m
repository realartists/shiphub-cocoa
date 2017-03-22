//
//  MarkdownFormattingController.m
//  ShipHub
//
//  Created by James Howard on 3/21/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "MarkdownFormattingController.h"
#import "WebKitExtras.h"

#import "JSON.h"

// touchbar identifiers
static NSString *const TBMarkdownItemId = @"TBMarkdown";
static NSString *const TBTextItemsId = @"TBText";
static NSString *const TBListItemsId = @"TBList";
static NSString *const TBHeadingItemsId = @"TBHeading";
static NSString *const TBTableItemId = @"TBTable";
static NSString *const TBLinkItemsId = @"TBLinks";
static NSString *const TBRuleItemId = @"TBRule";
static NSString *const TBCodeItemsId = @"TBCodes";
static NSString *const TBQuoteItemsId = @"TBQuotes";

@interface MarkdownFormattingController () <NSTouchBarDelegate> {
    NSString *_commentFocusKey;
}

@property (readwrite, nonatomic, getter=hasCommentFocus) BOOL commentFocus;

@end

@implementation MarkdownFormattingController

- (id)init {
    if (self = [super init]) {
        if (NSClassFromString(@"NSTouchBar") != nil) {
            _markdownTouchBar = [NSTouchBar new];
            _markdownTouchBar.customizationIdentifier = @"md";
            _markdownTouchBar.delegate = self;
            
            _markdownTouchBar.defaultItemIdentifiers = @[TBMarkdownItemId, NSTouchBarItemIdentifierOtherItemsProxy];
        }
    }
    return self;
}

- (nullable NSTouchBarItem *)touchBar:(NSTouchBar *)touchBar makeItemForIdentifier:(NSTouchBarItemIdentifier)identifier
{
    if ([identifier isEqualToString:TBMarkdownItemId]) {
        NSPopoverTouchBarItem *pop = [[NSPopoverTouchBarItem alloc] initWithIdentifier:identifier];
        NSImage *icon = [NSImage imageNamed:@"MarkdownTBIcon"];
        icon.template = YES;
        pop.collapsedRepresentationImage = icon;
        
        NSTouchBar *popBar = [NSTouchBar new];
        popBar.delegate = self;
        popBar.customizationIdentifier = @"mditems";
        popBar.delegate = self;
        
        popBar.defaultItemIdentifiers = @[TBTextItemsId, TBListItemsId, TBTableItemId, TBLinkItemsId, TBCodeItemsId, TBQuoteItemsId];
        
        pop.popoverTouchBar = popBar;
        
        return pop;
    } else if ([identifier isEqualToString:TBTextItemsId]) {
        NSImage *bold = [NSImage imageNamed:NSImageNameTouchBarTextBoldTemplate];
        NSImage *italic = [NSImage imageNamed:NSImageNameTouchBarTextItalicTemplate];
        NSImage *strike = [NSImage imageNamed:NSImageNameTouchBarTextStrikethroughTemplate];
        bold.template = italic.template = strike.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[bold, italic, strike] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbText:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBListItemsId]) {
        NSImage *ulImage = [NSImage imageNamed:NSImageNameTouchBarTextListTemplate];
        NSImage *olImage = [NSImage imageNamed:@"MarkdownTBOrderedList"];
        NSImage *taskLImage = [NSImage imageNamed:@"MarkdownTBTaskList"];
        ulImage.template = olImage.template = taskLImage.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[ulImage, olImage, taskLImage] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbList:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBHeadingItemsId]) {
        NSImage *headingInc = [NSImage imageNamed:@"MarkdownTBHeadingIncrease"];
        NSImage *headingDec = [NSImage imageNamed:@"MarkdownTBHeadingDecrease"];
        headingInc.template = headingDec.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[headingInc, headingDec] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbHeading:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBTableItemId]) {
        NSImage *table = [NSImage imageNamed:@"MarkdownTBTable"];
        //NSImage *rule = [NSImage imageNamed:@"MarkdownTBRule"];
        table.template = YES;
        // rule.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[table/*, rule*/] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbTableRule:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBLinkItemsId]) {
        //NSImage *image = [NSImage imageNamed:@"MarkdownTBImage"];
        NSImage *link = [NSImage imageNamed:@"MarkdownTBHyperlink"];
        //image.template = YES;
        link.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[/*image, */link] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbLink:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBCodeItemsId]) {
        NSImage *inLine = [NSImage imageNamed:@"MarkdownTBCodeInline"];
        NSImage *block = [NSImage imageNamed:@"MarkdownTBCodeBlock"];
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[inLine, block] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbCode:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    } else if ([identifier isEqualToString:TBQuoteItemsId]) {
        NSImage *inc = [NSImage imageNamed:@"MarkdownTBQuoteMore"];
        NSImage *dec = [NSImage imageNamed:@"MarkdownTBQuoteLess"];
        inc.template = dec.template = YES;
        
        NSSegmentedControl *seg = [NSSegmentedControl segmentedControlWithImages:@[inc, dec] trackingMode:NSSegmentSwitchTrackingMomentary target:self action:@selector(mdTbQuote:)];
        
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:identifier];
        item.view = seg;
        
        return item;
    }
    
    return nil;
}

- (void)setCommentFocus:(BOOL)commentFocus {
    if (_commentFocus != commentFocus) {
        _commentFocus = commentFocus;
        
        // update touch bar
        if ([self.delegate respondsToSelector:@selector(setTouchBar:)]) {
            self.delegate.touchBar = nil;
        }
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    return !(self.requireFocusToValidateActions) || _commentFocus;
}

- (void)registerJavaScriptAPI:(id)windowObject {
    __weak __typeof(self) weakSelf = self;
    
    if ([windowObject isKindOfClass:[WebScriptObject class]]) {
        [windowObject addScriptMessageHandlerBlock:^(NSDictionary *msg) {
            [weakSelf handleCommentFocus:msg];
        } name:@"inAppCommentFocus"];
    } else {
        [windowObject addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
            [weakSelf handleCommentFocus:msg.body];
        } name:@"inAppCommentFocus"];
    }
}

- (void)handleCommentFocus:(NSDictionary *)d {
    NSString *key = d[@"key"];
    BOOL state = [d[@"state"] boolValue];
    
    if (!state && (!_commentFocusKey || [_commentFocusKey isEqualToString:key])) {
        // blurred
        self.commentFocus = NO;
    } else if (state) {
        _commentFocusKey = [key copy];
        self.commentFocus = YES;
    }
}

#pragma mark - Formatting Controls

- (void)applyFormat:(NSString *)format {
    [self.delegate evaluateJavaScript:[NSString stringWithFormat:@"applyMarkdownFormat(%@)", [JSON stringifyObject:format withNameTransformer:nil]]];
}

- (IBAction)mdBold:(id)sender {
    [self applyFormat:@"bold"];
}

- (IBAction)mdItalic:(id)sender {
    [self applyFormat:@"italic"];
}

- (IBAction)mdStrike:(id)sender {
    [self applyFormat:@"strike"];
}

- (IBAction)mdIncreaseHeading:(id)sender {
    [self applyFormat:@"headingMore"];
}

- (IBAction)mdDecreaseHeading:(id)sender {
    [self applyFormat:@"headingLess"];
}

- (IBAction)mdUnorderedList:(id)sender {
    [self applyFormat:@"insertUL"];
}

- (IBAction)mdOrderedList:(id)sender {
    [self applyFormat:@"insertOL"];
}

- (IBAction)mdTaskList:(id)sender {
    [self applyFormat:@"insertTaskList"];
}

- (IBAction)mdTable:(id)sender {
    [self applyFormat:@"insertTable"];
}

- (IBAction)mdHorizontalRule:(id)sender {
    [self applyFormat:@"insertHorizontalRule"];
}

- (IBAction)mdCodeBlock:(id)sender {
    [self applyFormat:@"code"];
}

- (IBAction)mdCodeFence:(id)sender {
    [self applyFormat:@"codefence"];
}

- (IBAction)mdHyperlink:(id)sender {
    [self applyFormat:@"hyperlink"];
}

- (IBAction)mdAttachFile:(id)sender {
    [self applyFormat:@"attach"];
}

- (IBAction)mdIncreaseQuote:(id)sender {
    [self applyFormat:@"quoteMore"];
}

- (IBAction)mdDecreaseQuote:(id)sender {
    [self applyFormat:@"quoteLess"];
}

- (IBAction)mdIndent:(id)sender {
    [self applyFormat:@"indentMore"];
}

- (IBAction)mdOutdent:(id)sender {
    [self applyFormat:@"indentLess"];
}

- (IBAction)mdTbText:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdBold:nil]; break;
        case 1: [self mdItalic:nil]; break;
        case 2: [self mdStrike:nil]; break;
    }
}

- (IBAction)mdTbList:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdUnorderedList:nil]; break;
        case 1: [self mdOrderedList:nil]; break;
        case 2: [self mdTaskList:nil]; break;
    }
}

- (IBAction)mdTbHeading:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdIncreaseHeading:nil]; break;
        case 1: [self mdDecreaseHeading:nil]; break;
    }
}

- (IBAction)mdTbTableRule:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdTable:nil]; break;
        case 1: [self mdHorizontalRule:nil]; break;
    }
}

- (IBAction)mdTbLink:(id)sender {
    [self mdAttachFile:nil];
}

- (IBAction)mdTbCode:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdCodeBlock:nil]; break;
        case 1: [self mdCodeFence:nil]; break;
    }
}

- (IBAction)mdTbQuote:(id)sender {
    NSInteger seg = [sender selectedSegment];
    switch (seg) {
        case 0: [self mdIncreaseQuote:nil]; break;
        case 1: [self mdDecreaseQuote:nil]; break;
    }
}

- (IBAction)toggleCommentPreview:(id)sender {
    [self.delegate evaluateJavaScript:@"toggleCommentPreview()"];
}

@end

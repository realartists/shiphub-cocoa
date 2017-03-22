//
//  MarkdownFormattingController.h
//  ShipHub
//
//  Created by James Howard on 3/21/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol MarkdownFormattingControllerDelegate <NSObject>

// used to call applyMarkdownFormat in the JS
- (void)evaluateJavaScript:(NSString *)js;

@optional
@property (strong, readwrite) NSTouchBar *touchBar NS_AVAILABLE_MAC(10_12_2);

@end

@interface MarkdownFormattingController : NSResponder

@property (weak) IBOutlet id<MarkdownFormattingControllerDelegate> delegate;

@property (nonatomic, readonly, getter=hasCommentFocus) BOOL commentFocus;

@property BOOL requireFocusToValidateActions; // default is NO

// registers the window.inAppCommentFocus JS API
// windowObject is either a WebScriptObject or a WKUserContentController
- (void)registerJavaScriptAPI:(id)windowObject;

@property (nonatomic, readonly) NSTouchBar *markdownTouchBar;

- (void)applyFormat:(NSString *)format;

- (IBAction)mdBold:(id)sender;
- (IBAction)mdItalic:(id)sender;
- (IBAction)mdStrike:(id)sender;
- (IBAction)mdIncreaseHeading:(id)sender;
- (IBAction)mdDecreaseHeading:(id)sender;
- (IBAction)mdUnorderedList:(id)sender;
- (IBAction)mdOrderedList:(id)sender;
- (IBAction)mdTaskList:(id)sender;
- (IBAction)mdTable:(id)sender;
- (IBAction)mdHorizontalRule:(id)sender;
- (IBAction)mdCodeBlock:(id)sender;
- (IBAction)mdCodeFence:(id)sender;
- (IBAction)mdHyperlink:(id)sender;
- (IBAction)mdAttachFile:(id)sender;
- (IBAction)mdIncreaseQuote:(id)sender;
- (IBAction)mdDecreaseQuote:(id)sender;
- (IBAction)mdIndent:(id)sender;
- (IBAction)mdOutdent:(id)sender;

- (IBAction)toggleCommentPreview:(id)sender;

@end

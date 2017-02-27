//
//  IssueWebControllerInternal.h
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueWebController.h"
#import "EmptyLabelView.h"

#import <WebKit/WebKit.h>

@interface IssueWebController (Internal) <WebFrameLoadDelegate, WebUIDelegate, WebPolicyDelegate>

@property (readonly) WebView *web;
@property (readonly) EmptyLabelView *nothingLabel;

- (void)evaluateJavaScript:(NSString *)js;

#pragma mark - Subclassers Must Override
- (NSString *)webHtmlFilename; // html filename (e.g. issue.html)

- (void)reconfigureForReload;

#pragma mark - Subclassers May Override
// subclassers may override
- (NSString *)webResourcePath; // path in bundle where entry html file lives. (default IssueWeb)
- (NSInteger)webpackDevServerPort; // port on which the webpack dev server for this webapp lives (default 8080)
- (void)registerJavaScriptAPI:(WebScriptObject *)windowObject;
- (IBAction)reload:(id)sender;
- (IBAction)fixSpelling:(id)sender;

#pragma mark -

@end

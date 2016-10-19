//
//  IssueWeb2ControllerInternal.h
//  ShipHub
//
//  Created by James Howard on 10/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueWeb2Controller.h"
#import "EmptyLabelView.h"

#import <WebKit/WebKit.h>

@interface IssueWeb2Controller (Internal) <WKNavigationDelegate, WKUIDelegate>

@property (readonly) WKWebView *web;
@property (readonly) EmptyLabelView *nothingLabel;

- (void)evaluateJavaScript:(NSString *)js;

#pragma mark - Subclassers Must Override
- (NSInteger)webpackDevServerPort; // port on which the webpack dev server for this webapp lives (e.g. 8080)
- (NSString *)webResourcePath; // path in bundle where index.html lives. (e.g. IssueWeb)

- (void)reconfigureForReload;

#pragma mark - Subclassers May Override
// subclassers may override
- (void)registerJavaScriptAPI:(WKUserContentController *)cc NS_REQUIRES_SUPER;
- (IBAction)reload:(id)sender;
- (IBAction)fixSpelling:(id)sender;

#pragma mark -

@end

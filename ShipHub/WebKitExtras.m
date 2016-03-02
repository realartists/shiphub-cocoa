//
//  WebKitExtras.m
//  ShipHub
//
//  Created by James Howard on 2/29/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "WebKitExtras.h"

@interface ScriptMessageHandler : NSObject <WKScriptMessageHandler>
@property (copy) ScriptMessageHandlerBlock block;
@end

@implementation ScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    self.block(message);
}

- (void)dealloc {
    DebugLog(@"%@", self);
}

@end

@implementation WKUserContentController (Extras)

- (void)addScriptMessageHandlerBlock:(ScriptMessageHandlerBlock)block name:(NSString *)name {
    ScriptMessageHandler *handler = [ScriptMessageHandler new];
    handler.block = block;
    [self addScriptMessageHandler:handler name:name];
}

@end

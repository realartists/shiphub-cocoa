//
//  WebKitExtras.m
//  ShipHub
//
//  Created by James Howard on 2/29/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "WebKitExtras.h"

#import <JavaScriptCore/JavaScriptCore.h>

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
    
    NSString *namingSrc = [NSString stringWithFormat:@"window.%@ = window.webkit.messageHandlers.%@;", name, name];
    WKUserScript *naming = [[WKUserScript alloc] initWithSource:namingSrc injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [self addUserScript:naming];
}

@end

@interface LegacyScriptMessageHandler : NSObject

@property (copy) LegacyScriptMessageHandlerBlock block;

@end

@implementation WebScriptObject (Extras)

- (void)addScriptMessageHandlerBlock:(LegacyScriptMessageHandlerBlock)block name:(NSString *)name {
    LegacyScriptMessageHandler *handler = [LegacyScriptMessageHandler new];
    handler.block = block;
    [self setValue:handler forKey:name];
}

@end

@implementation LegacyScriptMessageHandler

+ (NSString *)webScriptNameForSelector:(SEL)selector {
    if (selector == @selector(postMessage:)) {
        return @"postMessage";
    }
    return nil;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)selector {
    return selector != @selector(postMessage:);
}

- (void)postMessage:(WebScriptObject *)msg {
    self.block([[msg JSValue] toDictionary]);
}

@end

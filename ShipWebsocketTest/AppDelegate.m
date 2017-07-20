//
//  AppDelegate.m
//  ShipLoginTester
//
//  Created by James Howard on 2/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "AppDelegate.h"

#import "AppDelegate.h"
#import "Auth.h"
#import "Extras.h"
#import "Error.h"
#import "Logging.h"
#import "ServerConnection.h"
#import "WSSyncConnection.h"
#import "WebKitExtras.h"

#import <sqlite3.h>
#import <SocketRocket/SRWebSocket.h>

@interface AppDelegate () <SyncConnectionDelegate, SRWebSocketDelegate, WKNavigationDelegate>

@property (weak) IBOutlet NSWindow *window;
@property IBOutlet NSTextView *text;
@property IBOutlet WKWebView *web;

@property NSMutableDictionary *logPipes;
@property WSSyncConnection *ws;
@property SRWebSocket *socketOrg;

@end

@implementation AppDelegate

- (IBAction)copyLog:(id)sender {
    NSAttributedString *s = _text.textStorage;
    
    [[NSPasteboard generalPasteboard] clearContents];
    [[NSPasteboard generalPasteboard] writeObjects:@[s]];
}

- (void)log:(NSString *)format, ... {
    NSString *msg;
    
    va_list args;
    va_start(args, format);
    msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    const char *newline = [msg hasSuffix:@"\n"] ? "" : "\n";
    
    msg = [NSString stringWithFormat:@"%@: %@%s", [NSDate date], msg, newline];
    
    RunOnMain(^{
        [_text.textStorage appendAttributedString:[NSAttributedString attributedStringWithPlainText:msg]];
        [_text scrollToEndOfDocument:nil];
    });
}

- (void)configureLogForFile:(FILE *)file {
    NSPipe* pipe = [NSPipe pipe];
    NSFileHandle* pipeReadHandle = [pipe fileHandleForReading];
    dup2([[pipe fileHandleForWriting] fileDescriptor], fileno(file));
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, [pipeReadHandle fileDescriptor], 0, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    dispatch_source_set_event_handler(source, ^{
        void* data = malloc(4096);
        ssize_t readResult = 0;
        do
        {
            errno = 0;
            readResult = read([pipeReadHandle fileDescriptor], data, 4096);
        } while (readResult == -1 && errno == EINTR);
        if (readResult > 0)
        {
            //AppKit UI should only be updated from the main thread
            dispatch_async(dispatch_get_main_queue(),^{
                NSString* stdOutString = [[NSString alloc] initWithBytesNoCopy:data length:readResult encoding:NSUTF8StringEncoding freeWhenDone:YES];
                if (![stdOutString containsString:@"_NSLayoutTreeLineFragmentRectForGlyphAtIndex"]) {
                    NSAttributedString* stdOutAttributedString = [[NSAttributedString alloc] initWithString:stdOutString];
                    [self.text.textStorage appendAttributedString:stdOutAttributedString];
                }
            });
        }
        else{free(data);}
    });
    dispatch_resume(source);
    
    if (!_logPipes) {
        _logPipes = [NSMutableDictionary new];
    }
    _logPipes[@(fileno(file))] = @[pipe, pipeReadHandle, source];
}

- (void)configureLog {
    [self configureLogForFile:stdout];
    [self configureLogForFile:stderr];
}

- (NSDictionary *)loadVersions:(NSString *)dbPath
{
    int err;
    sqlite3 *db = NULL;
    err = sqlite3_open_v2([dbPath fileSystemRepresentation], &db, SQLITE_OPEN_READONLY, NULL);
    
    if (!db) {
        [self log:@"Cannot open db: %s", sqlite3_errstr(err)];
        return nil;
    }
    
    sqlite3_stmt *stmt = NULL;
    const char *sql = "SELECT ZDATA FROM ZLOCALSYNCVERSION";
    sqlite3_prepare_v2(db, sql, (int)strlen(sql), &stmt, NULL);
    
    err = sqlite3_step(stmt);
    if (err != SQLITE_ROW) {
        [self log:@"Cannot fetch version info: %s", sqlite3_errmsg(db)];
        return @{};
    }
    
    int len = sqlite3_column_bytes(stmt, 0);
    const void *bytes = sqlite3_column_blob(stmt, 0);
    
    NSData *data = [NSData dataWithBytes:bytes length:len];
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    
    sqlite3_reset(stmt);
    sqlite3_finalize(stmt);
    
    sqlite3_close_v2(db);
    
    return dict ?: @{};
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self configureLog];
    
    [self log:@"Looking up last used login ...\n"];
    NSArray *parts = (__bridge_transfer NSArray *)CFPreferencesCopyAppValue((__bridge CFStringRef)DefaultsLastUsedAccountKey, CFSTR("com.realartists.Ship2"));
    AuthAccountPair *lastUsedLogin = nil;
    if ([parts count] == 2) {
        lastUsedLogin = [AuthAccountPair new];
        lastUsedLogin.login = parts[0];
        lastUsedLogin.shipHost = parts[1];
    }
    
    if (!lastUsedLogin) {
        [self log:@"ERROR: Could not find last used login in application defaults!\n"];
        return;
    }
    
    [self log:@"Found %@ (%@)\n\n", lastUsedLogin.login, lastUsedLogin.shipHost];
    
    [self log:@"Loading auth token from keychain ...\n"];
    Auth *auth = [Auth authWithAccountPair:lastUsedLogin];
    
    if (auth) {
        [self log:@"Loaded auth for %@ - %@ with token sha1 checksum: %@\n", auth.account.login, auth.account.ghIdentifier, [[auth.token dataUsingEncoding:NSUTF8StringEncoding] SHA1String]];
        
        NSString *shipDBPath = [[NSString stringWithFormat:@"~/Library/RealArtists/Ship2/LocalStore/%@/%@/ship.db", auth.account.shipHost, auth.account.shipIdentifier] stringByExpandingTildeInPath];
        
        [self log:@"Fetching most recent version data from %@\n", shipDBPath];
        
        NSDictionary *versions = [self loadVersions:shipDBPath];
        
        [self log:@"Connecting websocket ..."];
        _ws = [[WSSyncConnection alloc] initWithAuth:auth];
        _ws.delegate = self;
        [_ws syncWithVersions:versions];
        
    } else {
        [self log:@"ERROR: Failed to load auth!\n"];
    }
    
    [self configureWebsocketOrg];
    [self configureWebKit];
}

- (void)syncConnectionWillConnect:(SyncConnection *)sync {
    [self log:@"websocket will connect\n"];
}

- (void)syncConnectionDidConnect:(SyncConnection *)sync {
    [self log:@"websocket did connect\n"];
}

- (void)syncConnectionDidDisconnect:(SyncConnection *)sync {
    [self log:@"websocket did disconnect\n"];
}

- (void)syncConnection:(SyncConnection *)sync receivedEntries:(NSArray<SyncEntry *> *)entries versions:(NSDictionary *)versions progress:(double)progress
{
    [self log:@"websocket did receive %tu incremental log entries\n", entries.count];
}

- (BOOL)syncConnection:(SyncConnection *)connection didReceivePurgeIdentifier:(NSString *)purgeIdentifier {
    [self log:@"websocket received purge identifier %@\n", purgeIdentifier];
    return NO; // not purging
}

- (void)syncConnectionRequiresSoftwareUpdate:(SyncConnection *)sync {
    [self log:@"websocket requires software update\n"];
}

- (void)syncConnection:(SyncConnection *)sync didReceiveBillingUpdate:(NSDictionary *)update {
    
}

- (void)syncConnection:(SyncConnection *)sync didReceiveRateLimit:(NSDate *)limitedUntil {
    [self log:@"websocket received rate limit\n"];
}

- (void)syncConnectionRequiresUpdatedServer:(SyncConnection *)sync {
    [self log:@"websocket requires newer server\n"];
}

- (void)configureWebsocketOrg {
    [self log:@"connecting to echo.websocket.org"];
    
    NSURL *URL = [NSURL URLWithString:@"https://echo.websocket.org/"];
    _socketOrg = [[SRWebSocket alloc] initWithURL:URL];
    dispatch_queue_t q = dispatch_queue_create("echo.websocket.org", NULL);
    [_socketOrg setDelegateDispatchQueue:q];
    [_socketOrg setDelegate:self];
    dispatch_async(q, ^{
        [_socketOrg open];
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    [self log:@"echo.websocket.org didReceiveMessage: %@", [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding]];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    [self log:@"echo.websocket.org didOpen"];
    
    [webSocket send:[@"hello" dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    [self log:@"echo.websocket.org didFail: %@", error];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self log:@"echo.websocket.org didCloseWithCode: %d, reason: %@, clean: %d", code, reason, wasClean];
}
- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload
{
    [self log:@"echo.websocket.org didReceivePong"];
}

- (void)configureWebKit {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"WebKitDeveloperExtras": @YES}];
    
    [self log:@"configuring webkit websocket"];
    
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    WKUserContentController *uc = [WKUserContentController new];
    
    __weak __typeof(self) weakSelf = self;
    
    [uc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf log:@"ws://echo.websocket.org onopen: %@", msg.body];
    } name:@"wsopen"];
    
    [uc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf log:@"ws://echo.websocket.org onmessage: %@", msg.body];
    } name:@"wsmessage"];
    
    [uc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf log:@"ws://echo.websocket.org onclose: %@", msg.body];
    } name:@"wsclose"];
    
    [uc addScriptMessageHandlerBlock:^(WKScriptMessage *msg) {
        [weakSelf log:@"ws://echo.websocket.org onerror: %@", msg.body];
    } name:@"wserror"];
    
    config.userContentController = uc;
    
    WKWebView *web = _web = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    
    NSString *html =
    @"<!DOCTYPE html>\n"
    @"<html>\n"
    @"<head>\n"
    @"  <title></title>\n"
    @"  <script language='javascript'>\n"
    @"    var ws = new WebSocket('ws://echo.websocket.org');\n"
    @"    ws.onopen = function() {\n"
    @"      ws.send('hi');\n"
    @"      window.wsopen.postMessage({});\n"
    @"    };\n"
    @"    ws.onclose = function() {\n"
    @"      window.wsclose.postMessage({});\n"
    @"    }\n"
    @"    ws.onerror = function(err) {\n"
    @"      window.wserror.postMessage({});\n"
    @"    }\n"
    @"    ws.onmessage = function(msg) {\n"
    @"      window.wsmessage.postMessage({msg});\n"
    @"    }\n"
    @"    window.ws = ws;\n"
    @"    console.log('ws configured');\n"
    @"  </script>\n"
    @"</head>\n"
    @"<body>\n"
    @"\n"
    @"</body>\n"
    @"</html>\n";
    
    [web loadHTMLString:html baseURL:nil];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self log:@"webView didFinishNavigation"];
}

@end

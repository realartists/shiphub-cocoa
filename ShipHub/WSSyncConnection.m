//
//  WSSyncConnection.m
//  ShipHub
//
//  Created by James Howard on 5/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "WSSyncConnection.h"

#import "Auth.h"
#import "Error.h"
#import "Extras.h"
#import "IssueIdentifier.h"
#import "JSON.h"
#import "Reachability.h"

#import <SocketRocket/SRWebSocket.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

static NSString *const MessageFieldType = @"msg";

// Outgoing MessageTypes:
static NSString *const MessageHello = @"hello";
static NSString *const MessageViewing = @"viewing";

// Incoming MessageTypes:
static NSString *const MessageSync = @"sync";
static NSString *const MessagePurge = @"purge";
static NSString *const MessageBilling = @"billing";

// Shared Message fields
static NSString *const MessageFieldVersions = @"versions";

// Hello Message fields
static NSString *const MessageFieldClient = @"client";

// Sync Message fields
static NSString *const MessageFieldLogs = @"logs";
static NSString *const MessageFieldRemaining = @"remaining";

// Viewing Message fields
static NSString *const MessageFieldViewingIssue = @"issue";

// Hello (Reply) Message fields
static NSString *const MessageFieldPurgeIdentifier = @"purgeIdentifier";
static NSString *const MessageFieldUpgrade = @"upgrade";
static NSString *const MessageFieldNewVersion = @"newVersion";
static NSString *const MessageFieldReleaseNotes = @"releaseNotes";
static NSString *const MessageFieldURL = @"url";
static NSString *const MessageFieldRequired = @"required";

// Billing Message fields
static NSString *const MessageFieldBillingMode = @"mode";
static NSString *const MessageFieldBillingTrialEndDate = @"trialEndDate";

typedef NS_ENUM(uint8_t, MessageHeader) {
    MessageHeaderPlainText = 0,
    MessageHeaderDeflate = 1,
};

@interface WSSyncConnection () <SRWebSocketDelegate> {
    dispatch_queue_t _q;
    dispatch_source_t _heartbeat;
    
    NSDictionary *_syncVersions;
    NSURL *_syncURL;
    
    BOOL _socketOpen;
}

@property SRWebSocket *socket;
@property NSInteger logEntryTotalRemaining;

@property NSString *lastViewedIssueIdentifier;

@end

@implementation WSSyncConnection

- (id)initWithAuth:(Auth *)auth {
    if (self = [super initWithAuth:auth]) {
        _syncURL = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"https://%@/api/sync", auth.account.shipHost]];
        _q = dispatch_queue_create("WSSyncConnection", NULL);
        
        _heartbeat = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _q);
        __weak __typeof(self) weakSelf = self;
        dispatch_source_set_timer(_heartbeat, DISPATCH_TIME_NOW, 60.0 * NSEC_PER_SEC, 10.0 * NSEC_PER_SEC);
        dispatch_source_set_event_handler(_heartbeat, ^{
            id strongSelf = weakSelf;
            [strongSelf heartbeat];
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            dispatch_resume(_heartbeat);
        });
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:ReachabilityDidChangeNotification object:[Reachability sharedInstance]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(authChanged:) name:AuthStateChangedNotification object:nil];
        
#if TARGET_OS_IPHONE
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
#endif
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)authChanged:(NSNotification *)note {
    if (self.auth == note.object) {
        if (self.auth.authState == AuthStateValid) {
            dispatch_async(_q, ^{
                [self disconnect];
                [self connect];
            });
        } else {
            dispatch_async(_q, ^{
                [self disconnect];
            });
        }
    }
}

- (void)syncWithVersions:(NSDictionary *)versions {
    dispatch_async(_q, ^{
        _syncVersions = [versions copy];
        [self heartbeat];
    });
}

- (void)connect {
    dispatch_assert_current_queue(_q);
    
    if (!_socket && _syncVersions != nil && [[Reachability sharedInstance] isReachable] && self.auth.token) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate syncConnectionWillConnect:self];
        });
        
        self.logEntryTotalRemaining = -1;
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_syncURL];
        [self.auth addAuthHeadersToRequest:request];
        _socket = [[SRWebSocket alloc] initWithURLRequest:request protocols:@[@"V1"]];
        _socket.delegate = self;
        [_socket setDelegateDispatchQueue:_q];
        [_socket open];
    }
}

- (void)disconnect {
    dispatch_assert_current_queue(_q);
    
    if (_socket) {
        self.logEntryTotalRemaining = -1;
        _socket.delegate = nil;
        [_socket close];
        _socket = nil;
        _socketOpen = NO;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate syncConnectionDidDisconnect:self];
        });
    }
}

- (void)reset {
    dispatch_assert_current_queue(_q);
    
    [self disconnect];
    _syncVersions = nil;
}

- (void)refresh {
    dispatch_async(_q, ^{
        if (_socket) {
            self.logEntryTotalRemaining = -1;
            _socket.delegate = nil;
            [_socket close];
            _socket = nil;
            _socketOpen = NO;
            // don't tell delegate that we closed
        }
        
        [self connect];
    });
}

- (void)sendMessage:(NSDictionary *)message {
    dispatch_assert_current_queue(_q);
    
    if (_socketOpen) {
        NSError *err = nil;
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&err];
        NSMutableData *msgData = [[NSMutableData alloc] initWithLength:1 + bodyData.length];
        uint8_t *msgBytes = msgData.mutableBytes;
        msgBytes[0] = MessageHeaderPlainText;
        memcpy(msgBytes+1, bodyData.bytes, bodyData.length);
        if (err) {
            ErrLog(@"%@", err);
        }
        DebugLog(@"Sending %@", message);
        [_socket send:msgData];
    }
}

- (NSString *)clientVersion {
    static dispatch_once_t onceToken;
    static NSString *clientVersion;
    dispatch_once(&onceToken, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *appIdentifier = [bundle bundleIdentifier];
        NSString *appVersion = [bundle infoDictionary][@"CFBundleShortVersionString"];
        NSString *buildNumber = [bundle infoDictionary][@"CFBundleVersion"];
        NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
#if TARGET_OS_IPHONE
        NSString *platform = @"iOS";
#else
        NSString *platform = @"OS X";
#endif
        clientVersion = [NSString stringWithFormat:@"%@ %@ (%@), %@ %td.%td.%td", appIdentifier, appVersion, buildNumber, platform, osVersion.majorVersion, osVersion.minorVersion, osVersion.patchVersion];
    });
    return clientVersion;
}


- (void)sendHello {
    Trace();
    
    dispatch_assert_current_queue(_q);
    
    NSDictionary *hello = @{ MessageFieldType : MessageHello,
                             MessageFieldClient : [self clientVersion],
                             MessageFieldVersions : _syncVersions };
    
    [self sendMessage:hello];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)rawMessage {
    NSData *data = nil;
    if ([rawMessage isKindOfClass:[NSData class]]) {
        data = rawMessage;
    } else if ([rawMessage isKindOfClass:[NSString class]]) {
        data = [rawMessage dataUsingEncoding:NSUTF8StringEncoding];
    } else {
        ErrLog(@"Received unexpected message: %@", rawMessage);
        return;
    }
    
    if ([data length] < 1) {
        ErrLog(@"Received short message: %@", data);
        return;
    }
    
    MessageHeader header = ((uint8_t *)[data bytes])[0];
    NSData *bodyData = [data subdataWithRange:NSMakeRange(1, data.length-1)];
    if (header == MessageHeaderDeflate) {
        bodyData = [bodyData inflate];
        if (!bodyData) {
            ErrLog(@"Unable to inflate message");
            return;
        }
    }
    
    NSError *err = nil;
    NSDictionary *msg = [NSJSONSerialization JSONObjectWithData:bodyData options:0 error:&err];
    if (err) {
        ErrLog(@"%@", err);
        return;
    }
    
    DebugLog(@"Received msg: %@", msg);
    
    NSString *type = msg[MessageFieldType];
    
    if ([type isEqualToString:MessageHello]) {
        NSString *purgeIdentifier = msg[MessageFieldPurgeIdentifier];
        NSDictionary *upgrade = msg[MessageFieldUpgrade];
        
        BOOL mustUpgrade = [upgrade[@"required"] boolValue];
        if (mustUpgrade) {
            [self.delegate syncConnectionRequiresSoftwareUpdate:self];
            [self disconnect];
        }
        
        if ([self.delegate syncConnection:self didReceivePurgeIdentifier:purgeIdentifier]) {
            [self reset];
        }
    } else if ([type isEqualToString:MessageSync]) {
        _syncVersions = msg[MessageFieldVersions];
        
        NSArray *entries = [msg[MessageFieldLogs] arrayByMappingObjects:^id(id obj) {
            return [SyncEntry entryWithDictionary:obj];
        }];
        
        NSInteger remaining = [msg[MessageFieldRemaining] integerValue];
        NSInteger totalRemaining = remaining + [entries count];
        if (_logEntryTotalRemaining < 0 || totalRemaining > _logEntriesRemaining) {
            _logEntryTotalRemaining = totalRemaining;
        }
        if (remaining == 0) {
            _logEntryTotalRemaining = totalRemaining = 0;
        }
        double progress = 1.0;
        if (_logEntryTotalRemaining > 0) {
            progress = (double)(_logEntryTotalRemaining - remaining) / (double)_logEntryTotalRemaining;
        }
        
        self.logEntriesRemaining = remaining;
                
        [self.delegate syncConnection:self receivedEntries:entries versions:_syncVersions progress:progress];
    } else if ([type isEqualToString:MessageBilling]) {
        [self.delegate syncConnection:self didReceiveBillingUpdate:msg];
    } else {
        DebugLog(@"Unknown message: %@", type);
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    Trace();
    _socketOpen = YES;
    [self sendHello];
    
    if (_lastViewedIssueIdentifier) {
        NSDictionary *msg = @{ MessageFieldType : MessageViewing,
                               MessageFieldViewingIssue : _lastViewedIssueIdentifier };
        _lastViewedIssueIdentifier = nil;
        [self sendMessage:msg];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate syncConnectionDidConnect:self];
    });
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    ErrLog(@"%@", error);
    [self disconnect];
    
    NSNumber *httpError = error.userInfo[SRHTTPResponseErrorKey];
    if (httpError && [httpError integerValue] == 401) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.auth invalidate];
        });
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    DebugLog(@"webSocketDidCloseWithCode:%td reason:%@ clean:%d", code, reason, wasClean);
    _socketOpen = NO;
    [self disconnect];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload {
    Trace();
}

- (void)heartbeat {
    if (!_socket && [[Reachability sharedInstance] isReachable]) {
        [self connect];
    }
}

- (void)reachabilityChanged:(NSNotification *)note {
    DebugLog(@"%@", note.userInfo);
    dispatch_async(_q, ^{
        BOOL reachable = [note.userInfo[ReachabilityKey] boolValue];
        if (reachable && !_socket) {
            [self connect];
        } else if (!reachable && _socket) {
            [self disconnect];
        }
    });
}

- (void)enterForeground:(NSNotification *)note {
    Trace();
    dispatch_async(_q, ^{
        if (!_socket) {
            [self connect];
        }
    });
}

- (void)updateIssue:(id)issueIdentifier {
    NSDictionary *msg = @{ MessageFieldType : MessageViewing,
                           MessageFieldViewingIssue : issueIdentifier };
    dispatch_async(_q, ^{
        if (_socket) {
            [self sendMessage:msg];
        } else {
            _lastViewedIssueIdentifier = issueIdentifier;
        }
    });
}

@end

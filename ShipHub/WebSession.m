//
//  WebSession.m
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "WebSession.h"
#import "Auth.h"
#import "Extras.h"

#define REFRESH_INTERVAL (24.0 * 60.0 * 60.0)

static NSString *const UserSessionCookie = @"user_session";

@interface WebSession ()

@property CFAbsoluteTime lastUpdate;
@property NSTimer *refreshTimer;
@property dispatch_queue_t writeQ;
@property (copy) NSString *host;
@property (copy) NSString *path;
@property (strong) AuthAccount *account;
@property (strong) NSArray<NSHTTPCookie *> *cookies;

@end

@implementation WebSession

- (id)initWithAuthAccount:(AuthAccount *)account {
    if (self = [super init]) {
        _account = account;
        
        NSString *basePath = [@"~/Library/RealArtists/Ship2/CookieStore" stringByExpandingTildeInPath];
        _host = [account.ghHost stringByReplacingOccurrencesOfString:@"api." withString:@""];
        _path = [basePath stringByAppendingPathComponent:_host];
        _path = [_path stringByAppendingPathComponent:[account.ghIdentifier description]];
        
        [[NSFileManager defaultManager] createDirectoryAtPath:[_path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL];
        
        NSData *data = [NSData dataWithContentsOfFile:_path];
        if (data) {
            NSArray *cookiePlist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            _cookies = [cookiePlist arrayByMappingObjects:^id(id obj) {
                return [NSHTTPCookie cookieWithProperties:obj];
            }];
            
            _lastUpdate = [[[NSFileManager defaultManager] attributesOfItemAtPath:_path error:NULL][NSFileModificationDate] timeIntervalSinceReferenceDate];
        }
        
        _writeQ = dispatch_queue_create("WebSession.WriteQ", NULL);
        
        _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:REFRESH_INTERVAL weakTarget:self selector:@selector(refresh:) userInfo:nil repeats:YES];
        _refreshTimer.tolerance = 60.0;
    }
    return self;
}

- (id)initWithAuthAccount:(AuthAccount *)account initialCookies:(NSArray<NSHTTPCookie *> *)cookies
{
    if (self = [self initWithAuthAccount:account]) {
        if (cookies) {
            _cookies = [cookies copy];
            _lastUpdate = CFAbsoluteTimeGetCurrent();
            [self writeCookies:_cookies];
        }
    }
    return self;
}

- (void)dealloc {
    [_refreshTimer invalidate];
}

- (void)refresh:(NSTimer *)timer {
    Trace();
    
    if (!_cookies) {
        DebugLog(@"Nothing to refresh");
        return;
    }
    
    CFAbsoluteTime diff = CFAbsoluteTimeGetCurrent() - _lastUpdate;
    if (diff < REFRESH_INTERVAL-60.0) {
        DebugLog(@"Bailing early. diff %f", diff);
        return;
    }
    
    NSURL *refreshURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@", _host]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:refreshURL];
    [self addToRequest:request];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *http = (id)response;
        DebugLog(@"http response: %@", http);
        
        [self updateSessionWithResponse:http];
    }] resume];
}

- (void)writeCookies:(NSArray<NSHTTPCookie *> *)cookies {
    dispatch_async(_writeQ, ^{
        NSArray *cookiePlist = [cookies arrayByMappingObjects:^id(NSHTTPCookie * obj) {
            return [obj properties];
        }];
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:cookiePlist format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        [data writeToFile:_path atomically:YES];
    });
}

- (BOOL)updateSessionWithResponse:(NSHTTPURLResponse *)response {
    DebugLog(@"%@", response);
    
    if (![[response.URL host] isEqualToString:_host]) {
        DebugLog(@"ignoring response to %@", response.URL);
        return NO;
    }
    
    NSArray *cookies = [[self class] sessionCookiesInResponse:response];
    
    if (cookies) {
        _cookies = cookies;
        [self writeCookies:cookies];
        return YES;
    }
    
    return NO;
}

- (void)addToRequest:(NSMutableURLRequest *)request {
    if (!_cookies) {
        DebugLog(@"No cookies");
        return;
    }
    
    NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:_cookies];
    for (id key in headers) {
        id value = headers[key];
        [request setValue:value forHTTPHeaderField:key];
    }
}

+ (NSArray<NSHTTPCookie *> *)sessionCookiesInResponse:(NSHTTPURLResponse *)response {
    NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields forURL:response.URL];
    
    BOOL hasSession = [cookies containsObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"name = %@", UserSessionCookie]];
    if (!hasSession) {
        DebugLog(@"ignoring response because cookies don't contain %@: %@", UserSessionCookie, cookies);
    }
    
    return hasSession ? cookies : nil;
}

@end

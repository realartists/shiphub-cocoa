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

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property IBOutlet NSTextView *text;

@property NSMutableDictionary *logPipes;

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
    
    [_text.textStorage appendAttributedString:[NSAttributedString attributedStringWithPlainText:msg]];
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
                NSAttributedString* stdOutAttributedString = [[NSAttributedString alloc] initWithString:stdOutString];
                [self.text.textStorage appendAttributedString:stdOutAttributedString];
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
        
        [self log:@"Testing token with %@ ...\n", auth.account.ghHost];
        
        NSMutableURLRequest *gh = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://%@/user", auth.account.ghHost]]];
        gh.HTTPMethod = @"GET";
        [auth addAuthHeadersToRequest:gh];
        
        [[[NSURLSession sharedSession] dataTaskWithRequest:gh completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            RunOnMain(^{
                NSHTTPURLResponse *http = (id)response;
                NSString *body = @"";
                if ([data length]) {
                    body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                }
                if (error) {
                    [self log:@"ERROR: %@: %@\n", auth.account.ghHost, error];
                } else if (http.statusCode < 200 || http.statusCode >= 400) {
                    [self log:@"ERROR: %@ http error code: %td body:\n%@\n\n", auth.account.ghHost, http.statusCode, body];
                } else {
                    [self log:@"%@ login success\n", auth.account.ghHost];
                    [self log:@"Testing token with %@ ...\n", auth.account.shipHost];
                    
                    ServerConnection *conn = [[ServerConnection alloc] initWithAuth:auth];
                    [conn perform:@"GET" on:@"/user" forGitHub:YES headers:nil body:nil completion:^(id jsonResponse, NSError *shipError) {
                        RunOnMain(^{
                            if (shipError) {
                                [self log:@"ERROR: %@: %@\n", auth.account.shipHost, shipError];
                            } else {
                                [self log:@"%@ login success\n", auth.account.shipHost];
                            }
                        });
                    }];
                }
            });
        }] resume];
        
    } else {
        [self log:@"ERROR: Failed to load auth!\n"];
    }
}


@end

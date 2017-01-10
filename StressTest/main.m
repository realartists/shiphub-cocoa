//
//  main.m
//  StressTest
//
//  Created by James Howard on 1/6/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

#import "Auth.h"
#import "SqlUtil.h"
#import "WSSyncConnection.h"
#import "Logging.h"

static const NSInteger MAX_PARALLEL = 1;
static NSString *const SHIP_HOST = @"shiphubjames.ngrok.io";
static const NSTimeInterval MAX_LATENCY = 180.0; // maximum time to wait for initial sync

@interface Test : NSObject

- (void)run;

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        Test *t = [Test new];
        [t run];
    }
    return 0;
}

@interface Run : NSObject

@property NSString *login;
@property NSString *token;
@property int identifier;
@property NSArray<NSString *> *expectedRepos;

- (void)runWithCompletion:(void (^)(BOOL success))completion;

@end

@implementation Test

- (void)run {
    NSMutableArray *runs = [NSMutableArray new];
    
    {
        Run *run = [Run new];
        run.login = @"fpotter-test";
        run.token = @"";
        run.identifier = 19828132;
        run.expectedRepos = @[@"somerepo"];
        [runs addObject:run];
    }
    
    {
        Run *run = [Run new];
        run.login = @"fpotter-test2";
        run.token = @"";
        run.identifier = 24905538;
        run.expectedRepos = @[@"somerepo"];
        [runs addObject:run];
    }
    
    {
        Run *run = [Run new];
        run.login = @"fpotter";
        run.token = @"";
        run.identifier = 83509;
        run.expectedRepos = @[@"shiphub-cocoa", @"shiphub-server"];
        [runs addObject:run];
    }
    
    
    {
        Run *run = [Run new];
        run.login = @"kogir";
        run.token = @"";
        run.identifier = 87309;
        run.expectedRepos = @[@"shiphub-cocoa", @"shiphub-server"];
        [runs addObject:run];
    }
    
    {
        Run *run = [Run new];
        run.login = @"james-howard";
        run.token = @"";
        run.identifier = 2006254;
        run.expectedRepos = @[@"shiphub-cocoa", @"shiphub-server"];
        [runs addObject:run];
    }
    
    
    NSLog(@"Loaded %td users to connect to %@ with MAX_PARALLEL = %td", runs.count, SHIP_HOST, MAX_PARALLEL);
    
    dispatch_queue_t workQ = dispatch_queue_create("TestQ", NULL);
    dispatch_semaphore_t sema = dispatch_semaphore_create(MAX_PARALLEL);
    dispatch_async(workQ, ^{
        for (Run *run in runs) {
            dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
            NSLog(@"Beginning run for user %@", run.login);
            [run runWithCompletion:^(BOOL success) {
                NSLog(@"Run completes with success:%d for user %@", success, run.login);
                if (!success) {
                    exit(1);
                }
                dispatch_semaphore_signal(sema);
            }];
        }
        
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        NSLog(@"Successfully processed %td users", runs.count);
        exit(0);
    });
    
    CFRunLoopRun();
}

@end

@interface Auth (Internal)

@property (readwrite, strong) AuthAccount *account;
@property (readwrite, copy) NSString *token;
@property (readwrite, copy) NSString *ghToken;
@property (readwrite, strong) WebSession *webSession;

@property (readwrite) AuthState authState;

@end

@interface Run () <SyncConnectionDelegate>

@property NSMutableSet *remainingRepos;
@property dispatch_queue_t syncQ;

@property (copy) void (^completion)(BOOL success);

@end

@implementation Run

- (void)loginWithCompletion:(void (^)(BOOL))completion {
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/api/authentication/login",
                                       SHIP_HOST]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
    
    NSDictionary *body = @{ @"accessToken" : self.token,
                            @"applicationId" : @"StressTest",
                            @"clientName" : @"StressTest" };
    
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    request.HTTPMethod = @"POST";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
        
        DebugLog(@"%@", http);
        if (data) {
            DebugLog(@"%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }
        
        if (http.statusCode != 200) {
            NSLog(@"User %@ got http status code %td", self.login, http.statusCode);
            completion(NO);
            return;
        }
        
        completion(YES);
        
    }] resume];
}

- (void)readFromWSWithCompletion:(void (^)(BOOL))completion {
    Auth *auth = [Auth new];
    auth.token = self.token;
    auth.ghToken = self.token;
    AuthAccount *account = [AuthAccount new];
    account.login = self.login;
    account.name = self.login;
    account.ghHost = SHIP_HOST;
    account.shipHost = SHIP_HOST;
    account.ghIdentifier = @(self.identifier);
    account.shipIdentifier = [@(self.identifier) description];
    auth.account = account;
    
    self.syncQ = dispatch_queue_create(NULL, NULL);
    self.completion = completion;
    self.remainingRepos = [NSMutableSet setWithArray:self.expectedRepos];
    
    WSSyncConnection *conn = [[WSSyncConnection alloc] initWithAuth:auth];
    conn.delegate = self;
    
    [conn syncWithVersions:@{}];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, MAX_LATENCY * NSEC_PER_SEC), _syncQ, ^{
        
        conn.delegate = nil;
        
        if (_remainingRepos.count != 0) {
            completion(NO);
        }
        self.completion = nil;
    });
}

- (void)runWithCompletion:(void (^)(BOOL))completion {
    [self loginWithCompletion:^(BOOL success) {
        if (!success) {
            completion(NO);
            return;
        }
        
        [self readFromWSWithCompletion:completion];
    }];
}

- (void)syncConnectionWillConnect:(SyncConnection *)sync {}
- (void)syncConnectionDidConnect:(SyncConnection *)sync {
    NSLog(@"WS connected for %@", self.login);
}
- (void)syncConnectionDidDisconnect:(SyncConnection *)sync {
    NSLog(@"WS disconnected for %@", self.login);
}

- (void)syncConnection:(SyncConnection *)sync receivedEntries:(NSArray<SyncEntry *> *)entries versions:(NSDictionary *)versions progress:(double)progress
{
    dispatch_async(_syncQ, ^{
        for (SyncEntry *e in entries) {
            if ([e.entityName isEqualToString:@"repo"]) {
                NSDictionary *repo = e.data;
                [_remainingRepos removeObject:repo[@"name"]];
            }
        }
        
        if (_remainingRepos.count == 0) {
            if (self.completion) {
                self.completion(YES);
                self.completion = nil;
            }
        }
    });
}

- (BOOL)syncConnection:(SyncConnection *)connection didReceivePurgeIdentifier:(NSString *)purgeIdentifier {
    return NO;
}

- (void)syncConnectionRequiresSoftwareUpdate:(SyncConnection *)sync
{
    DebugLog(@"Client out of date");
    exit(1);
}

- (void)syncConnection:(SyncConnection *)sync didReceiveBillingUpdate:(NSDictionary *)update { }

- (void)syncConnection:(SyncConnection *)sync didReceiveRateLimit:(NSDate *)limitedUntil { }

- (void)syncConnectionRequiresUpdatedServer:(SyncConnection *)sync {
    DebugLog(@"Server out of date");
    exit(1);
}

@end


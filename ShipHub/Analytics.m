#import "Analytics.h"

#include <sys/sysctl.h>

#import "AppDelegate.h"
#import "Auth.h"
#import "Logging.h"

static const double kMininumFlushDelay = 60.0;

static NSString *AnalyticsEventsPath() {
    return [@"~/Library/RealArtists/Ship2/AnalyticsEvents.plist" stringByExpandingTildeInPath];
}

// Borrowed in part from: http://stackoverflow.com/a/13360637
static NSString *MachineModel() {
    static NSString *str = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        size_t length = 0;
        sysctlbyname("hw.model", NULL, &length, NULL, 0);

        char *model = malloc(length * sizeof(char));
        sysctlbyname("hw.model", model, &length, NULL, 0);
        str = [NSString stringWithUTF8String:model];
        free(model);
    });
    return str;
}

static NSString *OperatingSystemMajorMinor() {
    NSOperatingSystemVersion version = [[NSProcessInfo processInfo] operatingSystemVersion];
    return [NSString stringWithFormat:@"%ld.%ld", version.majorVersion, version.minorVersion];
}

@implementation Analytics {
    NSMutableArray *_queueItems;
    CFTimeInterval _skipSendUntilAfterTime;
    NSString *_distinctID;
    BOOL _appWillTerminate;
    BOOL _waitingOnFlushToFinish;
    BOOL _flushScheduled;
}

+ (instancetype)sharedInstance {
    static Analytics *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[Analytics alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _queueItems = [NSMutableArray array];
        _distinctID = [[NSUserDefaults standardUserDefaults] stringForKey:DefaultsAnalyticsIDKey];
        if (_distinctID == nil) {
            _distinctID = [[NSUUID UUID] UUIDString];
            [[NSUserDefaults standardUserDefaults] setObject:_distinctID forKey:DefaultsAnalyticsIDKey];
        }
        _shipHost = DefaultShipHost();

        NSString *path = AnalyticsEventsPath();
        NSArray *archivedEvents = [NSArray arrayWithContentsOfFile:path];
        if (archivedEvents != nil) {
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            [_queueItems addObjectsFromArray:archivedEvents];
            [self scheduleFlushIfNeededWithMinimumDelay:kMininumFlushDelay];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillTerminate:)
                                                     name:NSApplicationWillTerminateNotification
                                                   object:nil];
    }
    return self;
}

- (void)appWillTerminate:(NSNotification *)notification {
    [NSThread cancelPreviousPerformRequestsWithTarget:self selector:@selector(flushToServer) object:nil];
    _appWillTerminate = YES;
    if (_queueItems.count > 0) {
        [_queueItems writeToFile:AnalyticsEventsPath() atomically:YES];
    }
}

- (void)scheduleFlushIfNeededWithMinimumDelay:(double)minimumDelay {
    if (!_flushScheduled && !_waitingOnFlushToFinish && _queueItems.count > 0 && !_appWillTerminate) {
        _flushScheduled = YES;
        [self performSelector:@selector(flushToServer)
                   withObject:nil
                   afterDelay:MAX(minimumDelay, _skipSendUntilAfterTime - CACurrentMediaTime())];
    }
}

- (void)flushToServer {
    NSAssert(!_appWillTerminate, @"Cannot flush after app termination started.");
    NSAssert(!_waitingOnFlushToFinish, @"Cannot flush while already flushing.");
    NSAssert(_queueItems.count > 0, @"Should not be asked to flush empty queue.");
    _flushScheduled = NO;

    NSArray *batch = [_queueItems subarrayWithRange:NSMakeRange(0, MIN(50, _queueItems.count))];

    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/analytics/track", self.shipHost]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                   timeoutInterval:30.0];
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:batch
                                                       options:0
                                                         error:&jsonError];
    NSAssert(jsonData, @"Failed to encode JSON: %@", jsonError);

    [req setHTTPMethod:@"POST"];
    [req setHTTPBody:jsonData];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    DebugLog(@"Flushing %ld events...", _queueItems.count);
    [[[NSURLSession sharedSession] dataTaskWithRequest:req
                                     completionHandler:
      ^(NSData *data, NSURLResponse *response, NSError *error) {
          dispatch_async(dispatch_get_main_queue(), ^{
              NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
              if (error) {
                  ErrLog(@"Flush failed with error: %@", error);
              } else if (httpResponse.statusCode >= 500 && httpResponse.statusCode <= 599) {
                  ErrLog(@"Flush failed with status (%ld)", httpResponse.statusCode);
              } else {
                  DebugLog(@"Flushed %ld events.", _queueItems.count);
                  [_queueItems removeObjectsInArray:batch];
              }

              NSInteger retryAfterSeconds = [httpResponse.allHeaderFields[@"Retry-After"] integerValue];
              if (retryAfterSeconds > 0.0) {
                  DebugLog(@"Server asked us to not send events for %ld seconds.", retryAfterSeconds);
                  _skipSendUntilAfterTime = CACurrentMediaTime() + retryAfterSeconds;
              }

              _waitingOnFlushToFinish = NO;
              [self scheduleFlushIfNeededWithMinimumDelay:kMininumFlushDelay];
          });
      }] resume];
    _waitingOnFlushToFinish = YES;
}

- (void)flush {
    NSAssert([NSThread isMainThread], @"Must run on main thread.");
    if (_flushScheduled) {
        [NSThread cancelPreviousPerformRequestsWithTarget:self selector:@selector(flushToServer) object:nil];
        _flushScheduled = NO;
    }
    [self scheduleFlushIfNeededWithMinimumDelay:0.0];
}

- (void)track:(NSString *)event {
    [self track:event properties:@{}];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties {
    NSAssert([NSThread isMainThread], @"Must run on main thread.");
    if ([self.shipHost isEqualToString:@"api.github.com"]) {
        // User is running against GHSyncConnection; no analytics for them.
        return;
    }

    NSMutableDictionary *mutableProperties = [properties mutableCopy];
    mutableProperties[@"time"] = @((NSInteger)([[NSDate date] timeIntervalSince1970]));
    mutableProperties[@"version"] = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    mutableProperties[@"distinct_id"] = _distinctID;
    mutableProperties[@"machine"] = MachineModel();
    mutableProperties[@"os"] = OperatingSystemMajorMinor();
    mutableProperties[@"locale"] = [[NSLocale currentLocale] localeIdentifier];

    AppDelegate *delegate = [AppDelegate sharedDelegate];
    if (delegate.auth && delegate.auth.account) {
        mutableProperties[@"login"] = delegate.auth.account.login;
    }

    [_queueItems addObject:@{@"event" : event,
                             @"properties" : mutableProperties,
                             }];

    if (_queueItems.count > 5000) {
        [_queueItems removeObjectAtIndex:0];
    }

    [self scheduleFlushIfNeededWithMinimumDelay:kMininumFlushDelay];
}

@end

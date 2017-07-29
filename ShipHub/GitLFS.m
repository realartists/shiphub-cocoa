//
//  GitLFS.m
//  ShipHub
//
//  Created by James Howard on 7/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "GitLFS.h"

#import "Extras.h"
#import "Error.h"


@interface GitLFSURLSessionDelegate : NSObject <NSURLSessionDataDelegate>

+ (instancetype)delegateWithProgress:(NSProgress *)progress;

- (void)followTasks:(NSArray<NSURLSessionTask *> *)tasks completion:(void (^)(NSArray<URLSessionResult *> *))completion;

@end

@interface GitLFSObject ()

@property NSURL *downloadURL;
@property NSDictionary *downloadHeaders;

@end

@implementation GitLFSObject

+ (instancetype)objectWithOid:(NSString *)oid size:(NSNumber *)size {
    GitLFSObject *obj = [self new];
    obj.oid = oid;
    obj.size = size;
    return obj;
}

@end

@interface GitLFS ()

@property (readwrite, weak) GitRepo *repo;

@end

@implementation GitLFS

- (instancetype)initWithRepo:(GitRepo *)repo {
    if (self = [super init]) {
        self.repo = repo;
    }
    return self;
}

- (void)fetchObjects:(NSArray<GitLFSObject *> *)objects withProgress:(NSProgress *)progress completion:(GitLFSCompletion)completion completionQueue:(dispatch_queue_t)completionQueue
{
    if (progress.cancelled) {
        dispatch_async(completionQueue, ^{
            completion(nil, [NSError cancelError]);
        });
        return;
    }
    
    /*
     $ curl -X POST --data '{"operation":"download", "transfers":["basic"], "objects":[{"oid":"fd33a4ed04a19c6e76dc8db70a6512ff76ab47cd9851a4d3a6bbff4aeab70c68", "size":141635}]}' -H 'Accept: application/vnd.git-lfs+json' -H 'Content-Type: application/vnd.git-lfs+json' -u "$GITHUB_API_TOKEN:x-oauth-basic" https://github.com/james-howard/lfs.git/info/lfs/objects/batch
    {
      "objects": [
        {
          "oid": "fd33a4ed04a19c6e76dc8db70a6512ff76ab47cd9851a4d3a6bbff4aeab70c68",
          "size": 141635,
          "actions": {
            "download": {
              "href": "https://github-cloud.s3.amazonaws.com/alambic/media/153300650/fd/33/fd33a4ed04a19c6e76dc8db70a6512ff76ab47cd9851a4d3a6bbff4aeab70c68?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIMWPLRQEC4XCWWPA%2F20170728%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20170728T221440Z&X-Amz-Expires=86400&X-Amz-Signature=7e3d4ea419341b98c5db6e093a53d8c1dab8f4a9868bc39f7f8e2c41ff2abef3&X-Amz-SignedHeaders=host&actor_id=2006254&token=1",
              "expires_at": "2017-07-29T22:14:40Z",
              "expires_in": 3600
            }
          }
        }
      ]
    }
    */
    
    NSArray *lfsObjs = [objects arrayByMappingObjects:^id(GitLFSObject *obj) {
        return @{ @"oid" : obj.oid, @"size" : obj.size };
    }];
    
    // phase 1, ask the bulk endpoint for our objects.
    NSDictionary *batchInfo = @{ @"operation": @"download",
                                 @"transfers" : @[@"basic"],
                                 @"objects" : lfsObjs };
    
    NSURL *batchURL = [_remoteBaseURL URLByAppendingPathComponent:@"/info/lfs/objects/batch"];
    
    NSMutableURLRequest *batchReq = [NSMutableURLRequest requestWithURL:batchURL];
    [batchReq addBasicAuthorizationHeaderForUsername:_remoteUsername password:_remotePassword];
    [batchReq setValue:@"application/vnd.git-lfs+json" forHTTPHeaderField:@"Content-Type"];
    [batchReq setValue:@"application/vnd.git-lfs+json" forHTTPHeaderField:@"Accept"];
    [batchReq setHTTPMethod:@"POST"];
    [batchReq setHTTPBody:[NSJSONSerialization dataWithJSONObject:batchInfo options:0 error:NULL]];
    
    NSURLSessionDataTask *batchTask = [[NSURLSession sharedSession] dataTaskWithRequest:batchReq completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *http = (id)response;
        
        if (!error && (http.statusCode != 200 || !data)) {
            error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        if (!error) {
            NSError *jsonErr = nil;
            NSDictionary *downloadInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            
            if (jsonErr) {
                error = jsonErr;
            } else {
                @try {
                    NSDictionary *objectsByOid = [NSDictionary lookupWithObjects:downloadInfo[@"objects"] keyPath:@"oid"];
                    for (GitLFSObject *neededObj in objects) {
                        NSDictionary *replyObj = objectsByOid[neededObj.oid];
                        if (!replyObj) {
                            error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
                            break;
                        }
                        NSDictionary *download = replyObj[@"actions"][@"download"];
                        neededObj.downloadURL = [NSURL URLWithString:download[@"href"]];
                        neededObj.downloadHeaders = download[@"header"];
                    }
                } @catch (id exc) {
                    ErrLog(@"Error parsing LFS response: %@", exc);
                    error = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
                }
            }
        }
        
        if (error) {
            dispatch_async(completionQueue, ^{
                completion(nil, error);
            });
        } else {
            progress.completedUnitCount = 0;
            progress.totalUnitCount = [[objects valueForKeyPath:@"@sum.size"] longLongValue];
            
            NSArray *dlReqs = [objects arrayByMappingObjects:^id(GitLFSObject *obj) {
                NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:obj.downloadURL];
                if (obj.downloadHeaders.count) {
                    req.allHTTPHeaderFields = obj.downloadHeaders;
                }
                return req;
            }];
            
            GitLFSURLSessionDelegate *dlDelegate = [GitLFSURLSessionDelegate delegateWithProgress:progress];
            
            NSURLSession *dlSession = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:dlDelegate delegateQueue:nil];
            
            NSArray *tasks = [dlReqs arrayByMappingObjects:^id(NSURLRequest *req) {
                return [dlSession dataTaskWithRequest:req];
            }];
            
            [tasks makeObjectsPerformSelector:@selector(resume)];
            
            [dlDelegate followTasks:tasks completion:^(NSArray<URLSessionResult *> *results) {
                NSError *anyError = [URLSessionResult anyErrorInResults:results];
                if (anyError) {
                    dispatch_async(completionQueue, ^{
                        completion(nil, anyError);
                    });
                } else {
                    NSArray<NSData *> *datas = [results arrayByMappingObjects:^id(URLSessionResult *obj) {
                        return obj.data;
                    }];
                    dispatch_async(completionQueue, ^{
                        completion(datas, nil);
                    });
                }
            }];
            
            progress.cancellationHandler = ^{
                [dlSession invalidateAndCancel];
            };
        }
    }];
    
    progress.cancellationHandler = ^{
        [batchTask cancel];
    };
    
    [batchTask resume];
}

- (BOOL)attributesIndicateLFSAtPath:(NSString *)path treeSha:(NSString *)treeSha {
    return YES; // FIXME: Should inspect gitattributes here. However, this is a lot of work...
}

- (BOOL)isLFSAtPath:(NSString *)path text:(NSString *)text treeSha:(NSString *)treeSha outObject:(GitLFSObject *__autoreleasing *)outObject
{
    if (!text) return NO;
    
    static dispatch_once_t onceToken;
    static NSRegularExpression *re;
    dispatch_once(&onceToken, ^{
        NSString *pattern =
        @"^version https://git-lfs.github.com/spec/v1\\n"
        @"oid sha256:([A-Fa-f0-9]{64})\n"
        @"size (\\d+)$";
        re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL];
    });
    NSTextCheckingResult *match = [re firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (match) {
        if ([self attributesIndicateLFSAtPath:path treeSha:treeSha]) {
            if (outObject) {
                *outObject = [GitLFSObject objectWithOid:[text substringWithRange:[match rangeAtIndex:1]]
                                                    size:@([[text substringWithRange:[match rangeAtIndex:2]] longLongValue])];
            }
            return YES;
        }
    }
    return NO;
}

@end

@interface GitLFSURLSessionDelegate ()

@property NSArray *tasks;
@property NSArray<URLSessionResult *> *results;
@property NSArray<NSMutableData *> *data;
@property NSProgress *progress;
@property NSUInteger tasksCompleted;

@property (copy) void (^completion)(NSArray<URLSessionResult *> *);

@end

@implementation GitLFSURLSessionDelegate

+ (instancetype)delegateWithProgress:(NSProgress *)progress {
    GitLFSURLSessionDelegate *delegate = [[self alloc] init];
    delegate.progress = progress;
    return delegate;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    int64_t completedCount = 0;
    for (NSURLSessionDataTask *task in _tasks) {
        completedCount += task.countOfBytesReceived;
    }
    _progress.completedUnitCount = completedCount;
    
    NSUInteger idx = [_tasks indexOfObject:dataTask];
    if (idx != NSNotFound) {
        [_data[idx] appendData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error {
    NSUInteger idx = [_tasks indexOfObject:task];
    _results[idx].response = task.response;
    _results[idx].error = task.error;
    _results[idx].data = _data[idx];
    
    _tasksCompleted++;
    
    if (_tasksCompleted == _tasks.count) {
        _completion(_results);
    }
}

- (void)followTasks:(NSArray<NSURLSessionTask *> *)tasks completion:(void (^)(NSArray<URLSessionResult *> *))completion {
    _tasks = tasks;
    _tasksCompleted = 0;
    _completion = [completion copy];
    _results = [tasks arrayByMappingObjects:^id(id obj) {
        return [URLSessionResult new];
    }];
    _data = [tasks arrayByMappingObjects:^id(id obj) {
        return [NSMutableData new];
    }];
}

@end

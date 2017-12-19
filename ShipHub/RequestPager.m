//
//  RequestPager.m
//  ShipHub
//
//  Created by James Howard on 7/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "RequestPager.h"

#import "Error.h"

@interface RequestPager ()

@property Auth *auth;
@property dispatch_queue_t q;

@end

@implementation RequestPager

- (id)initWithAuth:(Auth *)auth {
    return [self initWithAuth:auth queue:dispatch_queue_create("RequestPager", NULL)];
}

- (id)initWithAuth:(Auth *)auth queue:(dispatch_queue_t)queue {
    NSParameterAssert(auth);
    NSParameterAssert(queue);
    
    if (self = [super init]) {
        self.auth = auth;
        self.q = queue;
        self.pageLimit = 100;
    }
    return self;
}

- (NSMutableURLRequest *)get:(NSString *)endpoint {
    return [self get:endpoint params:nil];
}

- (NSMutableURLRequest *)get:(NSString *)endpoint params:(NSDictionary *)params {
    return [self get:endpoint params:params headers:nil];
}

- (NSMutableURLRequest *)get:(NSString *)endpoint params:(NSDictionary *)params headers:(NSDictionary *)headers {
    NSMutableURLRequest *req = nil;
    if ([endpoint hasPrefix:@"https://"]) {
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
    } else {
        if (![endpoint hasPrefix:@"/"]) {
            endpoint = [@"/" stringByAppendingString:endpoint];
        }
        NSURLComponents *c = [NSURLComponents new];
        c.scheme = @"https";
        c.host = self.auth.account.ghHost;
        c.path = endpoint;
        
        NSMutableArray *qps = [NSMutableArray new];
        for (NSString *k in [params allKeys]) {
            id v = params[k];
            [qps addObject:[NSURLQueryItem queryItemWithName:k value:[v description]]];
        }
        [qps addObject:[NSURLQueryItem queryItemWithName:@"per_page" value:@"100"]];
        c.queryItems = qps;
        
        
        req = [NSMutableURLRequest requestWithURL:[c URL]];
        NSAssert(req.URL, @"Request must have a URL (1)");
    }
    NSAssert(req.URL, @"Request must have a URL (2)");
    req.HTTPMethod = @"GET";
    
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [_auth addAuthHeadersToRequest:req];
    
    for (NSString *key in [headers allKeys]) {
        [req setValue:headers[key] forHTTPHeaderField:key];
    }
    
    return req;
}

- (NSURLSessionDataTask *)jsonTask:(NSURLRequest *)request completion:(void (^)(id json, NSHTTPURLResponse *response, NSError *err))completion {
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(_q, ^{
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            if (![self.auth checkResponse:response]) {
                completion(nil, http, [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken]);
                return;
            } else if (error) {
                completion(nil, http, error);
                return;
            }
            
            NSError *err = nil;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
            if (err) {
                completion(nil, http, err);
                return;
            }
            
            completion(json, http, nil);
        });
    }];
    [task resume];
    return task;
}

- (NSArray<NSURLSessionDataTask *> *)tasks:(NSArray<NSURLRequest *>*)requests completion:(void (^)(NSArray<URLSessionResult *>* results))completion {
    NSArray<NSURLSessionDataTask *> *tasks = [[NSURLSession sharedSession] dataTasksWithRequests:requests completion:^(NSArray<URLSessionResult *> *results) {
        dispatch_async(_q, ^{
            completion(results);
        });
    }];
    // tasks are automatically resumed
    return tasks;
}

- (NSArray<NSURLSessionDataTask *> *)jsonTasks:(NSArray<NSURLRequest *>*)requests completion:(void (^)(NSArray *json, NSError *err))completion {
    return [self tasks:requests completion:^(NSArray<URLSessionResult *> *results) {
        NSError *anyError = nil;
        for (URLSessionResult *r in results) {
            NSInteger statusCode = ((NSHTTPURLResponse *)r.response).statusCode;
            anyError = r.error;
            if (![self.auth checkResponse:r.response]) {
                anyError = [NSError shipErrorWithCode:ShipErrorCodeNeedsAuthToken];
            }
            if (!anyError && statusCode != 200) {
                anyError = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
            }
            if (anyError) break;
        }
        if (anyError) {
            completion(nil, anyError);
            return;
        }
        
        NSMutableArray *json = [NSMutableArray arrayWithCapacity:results.count];
        for (URLSessionResult *r in results) {
            id v = [r json];
            if (r.error) {
                completion(nil, r.error);
                return;
            }
            
            [json addObject:v];
        }
        
        completion(json, nil);
    }];
}

#if 0
function pagedFetch(url) /* => Promise */ {
    var opts = { headers: { Authorization: "token " + debugToken }, method: "GET" };
    var initial = fetch(url, opts);
    return initial.then(function(resp) {
        var pages = []
        var link = resp.headers.get("Link");
        if (link) {
            var [next, last] = link.split(", ");
            var matchNext = next.match(/\<(.*?)\>; rel="next"/);
            var matchLast = last.match(/\<(.*?)\>; rel="last"/);
            console.log(matchNext);
            console.log(matchLast);
            if (matchNext && matchLast) {
                var second = parseInt(matchNext[1].match(/page=(\d+)/)[1]);
                var last = parseInt(matchLast[1].match(/page=(\d+)/)[1]);
                console.log("second: " + second + " last: " + last);
                for (var i = second; i <= last; i++) {
                    var pageURL = matchNext[1].replace(/page=\d+/, "page=" + i);
                    console.log("Adding pageURL: " + pageURL);
                    pages.push(fetch(pageURL, opts).then(function(resp) { return resp.json(); }));
                }
            }
        }
        return Promise.all([resp.json()].concat(pages));
    }).then(function(pages) {
        return pages.reduce(function(a, b) { return a.concat(b); });
    });
}
#endif

- (void)fetchSingleObject:(NSURLRequest *)rootRequest completion:(void (^)(NSDictionary *obj, NSError *err))completion {
    [self jsonTask:rootRequest completion:^(id json, NSHTTPURLResponse *response, NSError *err) {
        if (![json isKindOfClass:[NSDictionary class]]) {
            json = nil;
            if (!err) err = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        if (completion) completion(json, err);
    }];
}

- (void)fetchPaged:(NSURLRequest *)rootRequest completion:(void (^)(NSArray *data, NSError *err))completion {
    [self fetchPaged:rootRequest headersCompletion:^(NSArray *data, NSDictionary *headers, NSError *err) {
        if (completion) completion(data, err);
    }];
}

- (NSArray *)_pageRequestsWithRootRequest:(NSURLRequest *)rootRequest response:(NSHTTPURLResponse *)response {
    NSMutableArray *pageRequests = [NSMutableArray array];
    
    NSDictionary *headers = [response allHeaderFields];
    NSString *link = headers[@"Link"];
    
    if (link) {
        NSString *next, *last;
        NSArray *comps = [link componentsSeparatedByString:@", "];
        next = [comps firstObject];
        last = [comps lastObject];
        
        NSTextCheckingResult *matchNext = [[[NSRegularExpression regularExpressionWithPattern:@"\\<(.*?)\\>; rel=\"next\"" options:0 error:NULL] matchesInString:next options:0 range:NSMakeRange(0, next.length)] firstObject];
        NSTextCheckingResult *matchLast = [[[NSRegularExpression regularExpressionWithPattern:@"\\<(.*?)\\>; rel=\"last\"" options:0 error:NULL] matchesInString:last options:0 range:NSMakeRange(0, last.length)] firstObject];
        
        if (matchNext && matchLast) {
            NSString *nextPageURLStr = [next substringWithRange:[matchNext rangeAtIndex:1]];
            NSString *lastPageURLStr = [last substringWithRange:[matchLast rangeAtIndex:1]];
            NSRegularExpression *pageExp = [NSRegularExpression regularExpressionWithPattern:@"[\\&\\?]page=(\\d+)" options:0 error:NULL];
            NSTextCheckingResult *secondPageMatch = [[pageExp matchesInString:nextPageURLStr options:0 range:NSMakeRange(0, nextPageURLStr.length)] firstObject];
            NSTextCheckingResult *lastPageMatch = [[pageExp matchesInString:lastPageURLStr options:0 range:NSMakeRange(0, lastPageURLStr.length)] firstObject];
            
            if (secondPageMatch && lastPageMatch) {
                NSInteger secondIdx = [[nextPageURLStr substringWithRange:[secondPageMatch rangeAtIndex:1]] integerValue];
                NSInteger lastIdx = [[lastPageURLStr substringWithRange:[lastPageMatch rangeAtIndex:1]] integerValue];
                
                lastIdx = MIN(lastIdx, self.pageLimit);
                
                for (NSInteger i = secondIdx; i <= lastIdx; i++) {
                    NSString *pageURLStr = [nextPageURLStr stringByReplacingCharactersInRange:[secondPageMatch rangeAtIndex:1] withString:[NSString stringWithFormat:@"%td", i]];
                    [pageRequests addObject:[self get:pageURLStr
                                               params:nil
                                              headers:[rootRequest allHTTPHeaderFields]]];
                }
            }
        }
    }
    
    return pageRequests;
}

- (void)fetchPaged:(NSURLRequest *)rootRequest headersCompletion:(void (^)(NSArray *data, NSDictionary *headers, NSError *err))completion {
    NSParameterAssert(rootRequest);
    NSParameterAssert(completion);
    // Must first fetch the rootRequest and then can fetch each page
    DebugLog(@"%@", rootRequest);
    [self jsonTask:rootRequest completion:^(id first, NSHTTPURLResponse *response, NSError *err) {
        if (!err && ![first isKindOfClass:[NSArray class]]) {
            err = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        if (err) {
            completion(nil, nil, err);
            return;
        }
        
        NSDictionary *headers = [response allHeaderFields];
        NSArray *pageRequests = [self _pageRequestsWithRootRequest:rootRequest response:response];
        
        if (pageRequests.count) {
            [self jsonTasks:pageRequests completion:^(NSArray *rest, NSError *restErr) {
                if (restErr) {
                    ErrLog(@"%@", restErr);
                    completion(nil, headers, restErr);
                } else {
                    NSMutableArray *all = [first mutableCopy];
                    for (NSArray *page in rest) {
                        if (![page isKindOfClass:[NSArray class]]) {
                            restErr = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
                            break;
                        }
                        [all addObjectsFromArray:page];
                    }
                    DebugLog(@"%@ finished with %td pages: %tu items", rootRequest, 1+rest.count, all.count);
                    completion(all, headers, restErr);
                }
            }];
        } else {
            DebugLog(@"%@ finished with 1 page: %tu items", rootRequest, ((NSArray *)first).count);
            completion(first, headers, nil);
        }
        
    }];
}

- (void)streamPages:(NSURLRequest *)rootRequest pageHandler:(void (^)(NSArray *data))pageHandler completion:(void (^)(NSError *))completion
{
    NSParameterAssert(rootRequest);
    NSParameterAssert(pageHandler);
    NSParameterAssert(completion);
    
    [self jsonTask:rootRequest completion:^(id first, NSHTTPURLResponse *response, NSError *err) {
        if (!err && ![first isKindOfClass:[NSArray class]]) {
            err = [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse];
        }
        
        if (err) {
            completion(err);
            return;
        }
        
        pageHandler(first);
        
        NSArray *pageRequests = [self _pageRequestsWithRootRequest:rootRequest response:response];
        
        
        if (pageRequests.count) {
            __block NSUInteger pagesFinished = 0;
            __block NSError *pageErr = nil;
            NSUInteger totalPages = pageRequests.count;
            for (NSURLRequest *pageRequest in pageRequests) {
                [self jsonTask:pageRequest completion:^(id page, NSHTTPURLResponse *response2, NSError *err2) {
                    if (err2 && !pageErr) {
                        pageErr = err2;
                    }
                    
                    if (page && !err2) {
                        pageHandler(page);
                    }
                    
                    pagesFinished++;
                    
                    if (pagesFinished == totalPages) {
                        completion(pageErr);
                    }
                }];
            }
        } else {
            completion(nil);
        }
    }];
}

@end

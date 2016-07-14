//
//  RequestPager.h
//  ShipHub
//
//  Created by James Howard on 7/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "Auth.h"
#import "Extras.h"

@interface RequestPager : NSObject

- (id)initWithAuth:(Auth *)auth queue:(dispatch_queue_t)queue;

- (NSMutableURLRequest *)get:(NSString *)endpoint;
- (NSMutableURLRequest *)get:(NSString *)endpoint params:(NSDictionary *)params;
- (NSMutableURLRequest *)get:(NSString *)endpoint params:(NSDictionary *)params headers:(NSDictionary *)headers;

- (NSURLSessionDataTask *)jsonTask:(NSURLRequest *)request completion:(void (^)(id json, NSHTTPURLResponse *response, NSError *err))completion;

- (NSArray<NSURLSessionDataTask *> *)tasks:(NSArray<NSURLRequest *>*)requests completion:(void (^)(NSArray<URLSessionResult *>* results))completion;

- (NSArray<NSURLSessionDataTask *> *)jsonTasks:(NSArray<NSURLRequest *>*)requests completion:(void (^)(NSArray *json, NSError *err))completion;

- (void)fetchPaged:(NSURLRequest *)rootRequest completion:(void (^)(NSArray *data, NSError *err))completion;
- (void)fetchPaged:(NSURLRequest *)rootRequest headersCompletion:(void (^)(NSArray *data, NSDictionary *headers, NSError *err))completion;

@end
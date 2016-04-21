//
//  APIProxy.h
//  ShipHub
//
//  Created by James Howard on 4/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^APIProxyCompletion)(NSString *jsonResult, NSError *err);

@interface APIProxy : NSObject

+ (instancetype)proxyWithRequest:(NSDictionary *)request completion:(APIProxyCompletion)completion;

- (void)resume;

@end

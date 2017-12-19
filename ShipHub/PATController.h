//
//  PATController.h
//  Ship
//
//  Created by James Howard on 12/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Auth;

@interface PATController : NSObject

- (id)initWithAuth:(Auth *)auth;

@property (readonly) Auth *auth;

- (BOOL)handleResponse:(NSHTTPURLResponse *)response forInitialRequest:(NSURLRequest *)request completion:(void (^)(NSURLRequest *replayRequest, BOOL didPrompt))completion;

@end

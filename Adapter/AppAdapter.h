//
//  AppAdapter.h
//  ShipHub
//
//  Created by James Howard on 11/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@class Auth;

/* AppAdapter adds a layer of indirection for operations that are done in shared code but that have separate implementations in Ship and Reviewed By Me */
@protocol AppAdapter <NSObject>

@property (nonatomic, readonly, nullable) Auth *auth;

- (void)openURL:(NSURL *)URL;

@end

extern id<AppAdapter> SharedAppAdapter(void);

NS_ASSUME_NONNULL_END


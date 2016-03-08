//
//  BasicAuthController.h
//  ShipHub
//
//  Created by James Howard on 3/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol BasicAuthControllerDelegate;

@interface BasicAuthController : NSViewController

@property (weak) id<BasicAuthControllerDelegate> delegate;

@end

@protocol BasicAuthControllerDelegate <NSObject>

- (void)basicAuthController:(BasicAuthController *)c didAuthenticate:(NSDictionary *)authInfo;

@end

extern NSString *BasicAuthGitHubTokenKey;

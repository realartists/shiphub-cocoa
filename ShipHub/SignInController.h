//
//  SignInController.h
//  Ship
//
//  Created by James Howard on 1/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "AuthViewController.h"

@interface SignInController : AuthViewController

@property (nonatomic, copy) NSString *emailString;

- (void)attemptLoginWithOneTimeToken;

@end

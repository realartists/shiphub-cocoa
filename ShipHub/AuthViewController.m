//
//  AuthViewController.m
//  Ship
//
//  Created by James Howard on 8/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "AuthViewController.h"

@interface AuthViewController ()

@end

@implementation AuthViewController

- (AuthController *)authController {
    if (_authController) return _authController;
    return (AuthController *)[[self.view window] delegate];
}

@end

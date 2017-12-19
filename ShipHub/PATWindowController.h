//
//  PATWindowController.h
//  Ship
//
//  Created by James Howard on 12/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;

@interface PATWindowController : NSWindowController

- (id)initWithAuth:(Auth *)auth;

- (void)runWithCompletion:(void (^)(BOOL didSetPAT))completion;

@end

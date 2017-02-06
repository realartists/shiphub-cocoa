//
//  NewProjectController.h
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Repo;
@class Account;
@class Project;

@interface NewProjectController : NSWindowController

- (instancetype)initWithRepo:(Repo *)repo;
- (instancetype)initWithOrg:(Account *)org;

@property (readonly) Repo *repo;
@property (readonly) Account *org;

- (void)beginInWindow:(NSWindow *)parentWindow completion:(void (^)(Project *createdProject, NSError *error))completion;

@end

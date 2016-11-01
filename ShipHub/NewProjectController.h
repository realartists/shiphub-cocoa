//
//  NewProjectController.h
//  ShipHub
//
//  Created by James Howard on 9/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Repo;
@class Org;
@class Project;

@interface NewProjectController : NSWindowController

- (instancetype)initWithRepo:(Repo *)repo;
- (instancetype)initWithOrg:(Org *)org;

@property (readonly) Repo *repo;
@property (readonly) Org *org;

- (void)beginInWindow:(NSWindow *)parentWindow completion:(void (^)(Project *createdProject, NSError *error))completion;

@end

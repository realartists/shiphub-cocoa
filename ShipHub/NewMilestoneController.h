//
//  NewMilestoneController.h
//  ShipHub
//
//  Created by James Howard on 8/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Repo;
@class Milestone;

@interface NewMilestoneController : NSWindowController

- (instancetype)initWithInitialRepos:(NSArray<Repo *> *)repos initialReposAreRequired:(BOOL)required initialName:(NSString *)initialName;

- (void)beginInWindow:(NSWindow *)parentWindow completion:(void (^)(NSArray<Milestone *> *createdMilestones, NSError *error))completion;

@end

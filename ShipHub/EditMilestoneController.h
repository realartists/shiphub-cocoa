//
//  EditMilestoneController.h
//  Ship
//
//  Created by James Howard on 10/9/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Milestone;

@interface EditMilestoneController : NSWindowController

- (id)initWithMilestones:(NSArray<Milestone *> *)miles;

- (void)beginInWindow:(NSWindow *)parentWindow completion:(void (^)(NSArray<Milestone *> *updatedMilestones, NSError *error))completion;

@end

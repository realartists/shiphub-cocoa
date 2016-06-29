//
//  ResultsController.h
//  Ship
//
//  Created by James Howard on 8/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ResultsController : NSViewController

@property (nonatomic, strong) NSPredicate *predicate;

- (IBAction)refresh:(id)sender;

@property (getter=isInProgress) BOOL inProgress;

@property (nonatomic, assign) BOOL upNextMode; // if YES, the controller operates in Up Next mode, which allows for item reordering and removal.

@end

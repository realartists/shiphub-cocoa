//
//  SearchResultsController.h
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ResultsController.h"

@protocol ProblemSnapshot;

@interface SearchResultsController : ResultsController

@property BOOL autoupdates; // if YES, will listen for DataStore changes and automatically refresh its contents. Default is NO.

- (NSArray <id<ProblemSnapshot>> *)selectedProblemSnapshots;

@property (nonatomic, assign, getter=isBordered) BOOL bordered;

@end

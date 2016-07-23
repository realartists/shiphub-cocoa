//
//  CompletingTextField.h
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NSArray *(^CompleteTextBlock)(NSString *text);

@interface CompletingTextField : NSTextField

@property (copy) CompleteTextBlock complete;

@property (nonatomic, assign) BOOL showsChevron;

@property NSString *abortValue; // Value to use if aborted. If nil, will attempt to complete on abort editing (esc press).

@property BOOL cancelsOnExternalClick;

- (IBAction)showCompletions:(id)sender;

@property (nonatomic, assign) BOOL hideCompletions;

@end

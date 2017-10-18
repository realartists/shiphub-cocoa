//
//  LabelsFilterViewController.h
//  Ship
//
//  Created by James Howard on 10/9/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Label;
@protocol LabelsFilterViewControllerDelegate;

@interface LabelsFilterViewController : NSViewController

@property (nonatomic, readonly) NSPredicate *labelsPredicate;
@property (nonatomic, assign) BOOL showPredicateCombinedWarning;

@property (weak) id<LabelsFilterViewControllerDelegate> delegate;

- (void)setLabels:(NSArray<Label *> *)labels predicate:(NSPredicate *)labelsPredicate;

@end

@protocol LabelsFilterViewControllerDelegate <NSObject>

- (void)labelsFilterViewController:(LabelsFilterViewController *)controller didUpdateLabelsPredicate:(NSPredicate *)labelsPredicate shouldClosePopover:(BOOL)closePopover;

@end

//
//  LabelsFilterTableController.h
//  Ship
//
//  Created by James Howard on 10/16/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Label;

@protocol LabelsFilterTableControllerDelegate;

@interface LabelsFilterTableController : NSViewController

@property (nonatomic, copy, readonly) NSSet<NSString *> *selectedLabelNames;

// sender is expected to have already uniqued labels by name
- (void)setLabels:(NSArray<Label *> *)labels selected:(NSSet<NSString *> *)selectedLabelNames;

- (void)clearSearch;
- (void)clearSelections;

@property (weak) id<LabelsFilterTableControllerDelegate> delegate;

@end

@protocol LabelsFilterTableControllerDelegate <NSObject>

- (void)labelsFilterTableController:(LabelsFilterTableController *)controller didUpdateSelectedLabelNames:(NSSet<NSString *> *)selectedLabelNames;

@end

//
//  FilterBarViewController.h
//  ShipHub
//
//  Created by James Howard on 6/17/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol FilterBarViewControllerDelegate;

@interface FilterBarViewController : NSTitlebarAccessoryViewController

// The baseline predicate being applied to the displayed data, without any filter bar stuff added.
// This tells the FilterBar which fields to omit, as they're already specified.
// For example: If you've explicitly selected a milestone in the sidebar, then the filter bar
// won't show a milestone filter button.
@property (nonatomic, strong) NSPredicate *basePredicate;

// The predicate yielded by the user selections on the filter bar.
@property (readonly) NSPredicate *predicate;

- (void)clearFilters;
- (void)resetFilters:(NSPredicate *)defaultFilters;

@property (weak) id<FilterBarViewControllerDelegate> delegate;

- (void)removeFromWindow;
- (void)addToWindow:(NSWindow *)window;
@property (nonatomic, weak, readonly) NSWindow *window;

@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

@end

@protocol FilterBarViewControllerDelegate <NSObject>

- (void)filterBar:(FilterBarViewController *)vc didUpdatePredicate:(NSPredicate *)newPredicate;

@end

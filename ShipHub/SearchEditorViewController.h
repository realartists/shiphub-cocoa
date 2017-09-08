//
//  SearchEditorViewController.h
//  Ship
//
//  Created by James Howard on 7/23/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol SearchEditorViewControllerDelegate;

@interface SearchEditorViewController : NSViewController

@property (weak) id<SearchEditorViewControllerDelegate> delegate;

- (CGFloat)fullHeight;

- (void)hideScrollers;
- (void)showScrollers;

- (void)reset;

- (IBAction)helpButtonClicked:(id)sender;

- (IBAction)addCompoundPredicate:(id)sender;

@property (nonatomic) NSPredicate *predicate;

@end

@protocol SearchEditorViewControllerDelegate <NSObject>
@required

- (void)searchEditorViewControllerDidChangeFullHeight:(SearchEditorViewController *)vc;
- (void)searchEditorViewControllerDidChangePredicate:(SearchEditorViewController *)vc;

@end

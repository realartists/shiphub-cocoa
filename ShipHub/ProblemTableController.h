//
//  ProblemTableController.h
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ProblemSnapshot;

@protocol ProblemTableItem <NSObject>
@required
@property (nonatomic, readonly) id<NSCopying> identifier; // used for maintaining selection state
@property (nonatomic, readonly) NSNumber *problemIdentifier;

@optional
@property (nonatomic, readonly) NSInteger problemPopupIndex;
@property (nonatomic, readonly) id<ProblemSnapshot> problemSnapshot;

@end

@protocol ProblemTableControllerDelegate;

@interface ProblemTableController : NSViewController

@property (nonatomic, strong) NSArray /* id<ProblemTableItem> */ *tableItems;
- (void)setTableItems:(NSArray *)items clearSelection:(BOOL)clearSelection; // if clearSelection is NO, controller will attempt to maintain selection via item identifiers.
@property (weak) IBOutlet id<ProblemTableControllerDelegate> delegate;

@property (nonatomic, copy) NSString *popupColumnTitle;
@property (nonatomic, copy) NSArray /* NSString */ *popupItems; // if set, rows will have a popup menu at column 0 with these items in it.

@property (nonatomic, copy) NSSet /* NSString */ *defaultColumns; // Set of problem keyPaths corresponding to columns that are shown by default. Key paths on ProblemTableItem are info.problemIdentifier and info.problemPopupIndex. Key paths on the Problem itself are problem.title, problem.assignee, etc
+ (NSArray *)columnSpecs;

- (void)reloadProblems; // invalidate Problem cache and reload from disk/network
- (void)reloadProblemsAndClearSelection:(BOOL)invalidateSelection;

@property (nonatomic, readonly) BOOL loading;

@property (nonatomic, copy) NSString *autosaveName;

@property (nonatomic, readonly) NSArray *selectedProblemSnapshots;

@end

@protocol ProblemTableControllerDelegate <NSObject>
@optional
- (BOOL)problemTableController:(ProblemTableController *)controller shouldAcceptDrag:(NSNumber *)problemIdentifier;
- (BOOL)problemTableController:(ProblemTableController *)controller didAcceptDrag:(NSNumber *)problemIdentifier;

- (void)problemTableController:(ProblemTableController *)controller item:(id<ProblemTableItem>)item popupSelectedItemAtIndex:(NSInteger)index;
- (BOOL)problemTableController:(ProblemTableController *)controller deleteItem:(id<ProblemTableItem>)item;

@end

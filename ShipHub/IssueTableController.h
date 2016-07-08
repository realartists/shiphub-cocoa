//
//  ProblemTableController.h
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Issue;

@protocol IssueTableControllerDelegate;

@interface IssueTableController : NSViewController

@property (nonatomic, copy) NSArray<Issue *> *tableItems; // returns items in current sort order.

- (void)setTableItems:(NSArray *)items clearSelection:(BOOL)clearSelection; // if clearSelection is NO, controller will attempt to maintain selection via item identifiers.
@property (weak) IBOutlet id<IssueTableControllerDelegate> delegate;

@property (nonatomic, copy) NSSet /* NSString */ *defaultColumns; // Set of problem keyPaths corresponding to columns that are shown by default.
+ (NSArray *)columnSpecs;

@property (nonatomic, copy) NSString *autosaveName;

@property (nonatomic, readonly) NSArray *selectedProblemSnapshots;

- (void)selectSomething;
- (void)selectItemsByIdentifiers:(NSSet *)identifiers;

@property (nonatomic, assign) BOOL upNextMode;
@property (nonatomic, strong) NSViewController *emptyPlaceholderViewController;

@end

@protocol IssueTableControllerDelegate <NSObject>
@optional

- (BOOL)issueTableController:(IssueTableController *)controller shouldAcceptDrop:(NSArray *)issueIdentifiers;
// Used for dropping items from outside of the current controller
- (void)issueTableController:(IssueTableController *)controller didAcceptDrop:(NSArray *)issueIdentifiers aboveItemAtIndex:(NSInteger)idx;
// Used for re-ordering items within the current controller. self.tableItems will already be updated to reflect the new ordering.
- (void)issueTableController:(IssueTableController *)controller didReorderItems:(NSArray<Issue *> *)items aboveItemAtIndex:(NSInteger)idx;

- (BOOL)issueTableController:(IssueTableController *)controller deleteItems:(NSArray<Issue *> *)items;

- (void)issueTableController:(IssueTableController *)controller didChangeSelection:(NSArray<Issue *> *)selectedIssues userInitiated:(BOOL)userInitiated;

@end

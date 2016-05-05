//
//  ProblemTableController.h
//  Ship
//
//  Created by James Howard on 5/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Issue;

@protocol IssueTableItem <NSObject>
@required
@property (nonatomic, readonly) id<NSCopying> identifier; // used for maintaining selection state
@property (nonatomic, readonly) id issueFullIdentifier;

@optional
@property (nonatomic, readonly) NSInteger issuePopupIndex;
@property (nonatomic, readonly) Issue *issue;

@end

@protocol IssueTableControllerDelegate;

@interface IssueTableController : NSViewController

@property (nonatomic, strong) NSArray /* id<ProblemTableItem> */ *tableItems;
- (void)setTableItems:(NSArray *)items clearSelection:(BOOL)clearSelection; // if clearSelection is NO, controller will attempt to maintain selection via item identifiers.
@property (weak) IBOutlet id<IssueTableControllerDelegate> delegate;

@property (nonatomic, copy) NSString *popupColumnTitle;
@property (nonatomic, copy) NSArray /* NSString */ *popupItems; // if set, rows will have a popup menu at column 0 with these items in it.

@property (nonatomic, copy) NSSet /* NSString */ *defaultColumns; // Set of problem keyPaths corresponding to columns that are shown by default. Key paths on IssueTableItem are info.issueFullIdentifier and issuePopupIndex. Key paths on the Issue itself are title, assignee, etc
+ (NSArray *)columnSpecs;

- (void)reloadProblems; // invalidate Problem cache and reload from disk/network
- (void)reloadProblemsAndClearSelection:(BOOL)invalidateSelection;

@property (nonatomic, readonly) BOOL loading;

@property (nonatomic, copy) NSString *autosaveName;

@property (nonatomic, readonly) NSArray *selectedProblemSnapshots;

@end

@protocol IssueTableControllerDelegate <NSObject>
@optional
- (BOOL)issueTableController:(IssueTableController *)controller shouldAcceptDrag:(NSNumber *)problemIdentifier;
- (BOOL)issueTableController:(IssueTableController *)controller didAcceptDrag:(NSNumber *)problemIdentifier;

- (void)issueTableController:(IssueTableController *)controller item:(id<IssueTableItem>)item popupSelectedItemAtIndex:(NSInteger)index;
- (BOOL)issueTableController:(IssueTableController *)controller deleteItem:(id<IssueTableItem>)item;

- (void)issueTableController:(IssueTableController *)controller didChangeSelection:(NSArray<Issue *> *)selectedIssues;

@end

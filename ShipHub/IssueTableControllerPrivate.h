//
//  IssueTableControllerPrivate.h
//  ShipHub
//
//  Created by James Howard on 5/5/16.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "IssueTableController.h"

@protocol ProblemTableViewDelegate <NSTableViewDelegate>
@optional
- (BOOL)tableView:(NSTableView *)tableView handleKeyPressEvent:(NSEvent *)event; // return YES if delegate handled, NO if table should handle by itself

@end

@interface ProblemTableView : NSTableView

@property (weak) id<ProblemTableViewDelegate> delegate;

@end

@interface IssueTableController (Private) <NSTableViewDataSource, NSTableViewDelegate, ProblemTableViewDelegate>

@property (strong) IBOutlet NSTableView *table;

@property (strong) NSMutableArray *tableColumns; // NSTableView .tableColumns property doesn't preserve order, and we want this in our order.

@property (strong) NSMutableArray *items;

- (void)commonInit NS_REQUIRES_SUPER;

- (void)_makeColumns;

- (NSArray<Issue *> *)selectedItemsForMenu;
- (void)_sortItems;

- (NSArray<Issue *> *)selectedItems;
- (void)selectItems:(NSArray *)items;

+ (Class)tableClass; // returns [ProblemTableView class]. Subclassers may override.
- (BOOL)usesAlternatingRowBackgroundColors;

@end

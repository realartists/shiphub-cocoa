//
//  ProblemTableController.h
//  ShipHub
//
//  Created by James Howard on 5/5/16.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "IssueTableController.h"

@interface ProblemTableItem : NSObject

@property (strong) id<IssueTableItem> info;
@property (strong) Issue *issue;

- (id<NSCopying>)identifier;

+ (instancetype)itemWithInfo:(id<IssueTableItem>)info;

@end

@interface IssueTableController (Private) <NSTableViewDataSource, NSTableViewDelegate>

@property (strong) IBOutlet NSTableView *table;

@property (strong) NSMutableArray *tableColumns; // NSTableView .tableColumns property doesn't preserve order, and we want this in our order.

@property (strong) NSMutableArray *items;

- (void)commonInit NS_REQUIRES_SUPER;

- (NSArray<ProblemTableItem *> *)selectedItemsForMenu;
- (void)_sortItems;

- (NSArray<ProblemTableItem *> *)selectedItems;
- (void)selectItems:(NSArray *)items;

@end

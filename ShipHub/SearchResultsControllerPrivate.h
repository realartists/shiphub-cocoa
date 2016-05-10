//
//  SearchResultsControllerPrivate.h
//  ShipHub
//
//  Created by James Howard on 5/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "SearchResultsController.h"
#import "IssueTableController.h"

@interface SearchResultsController (Private)

@property IssueTableController *table;

- (void)didUpdateItems;

@end

@interface SearchTableItem : NSObject <IssueTableItem>

@property (nonatomic, strong) Issue *issue;

@end

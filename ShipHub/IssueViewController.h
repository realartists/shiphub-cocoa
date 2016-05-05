//
//  IssueViewController.h
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Issue;

@interface IssueViewController : NSViewController

@property (nonatomic, getter=isColumnBrowser) BOOL columnBrowser;

@property (nonatomic) Issue *issue;

- (void)configureNewIssue;

@end

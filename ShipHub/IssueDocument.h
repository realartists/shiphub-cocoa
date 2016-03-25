//
//  IssueDocument.h
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IssueViewController.h"

@interface IssueDocument : NSDocument

@property IBOutlet IssueViewController *issueViewController;

@end

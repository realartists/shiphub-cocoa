//
//  CompactIssueCellViewController.h
//  ShipHub
//
//  Created by James Howard on 5/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Issue;

@interface CompactIssueCellViewController : NSViewController

@property (nonatomic) Issue *issue;

+ (CGFloat)cellHeight;

- (void)prepareForReuse;

@end

@interface CompactIssueRowView : NSTableRowView

@property (weak, readonly) CompactIssueCellViewController *controller;

@end

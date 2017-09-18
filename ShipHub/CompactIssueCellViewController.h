//
//  CompactIssueCellViewController.h
//  ShipHub
//
//  Created by James Howard on 5/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, CompactIssueDateType) {
    CompactIssueDateTypeCreatedAt = 0,
    CompactIssueDateTypeUpdatedAt,
    CompactIssueDateTypeClosedAt
};

@class Issue;

@interface CompactIssueCellViewController : NSViewController

@property (nonatomic) Issue *issue;

+ (CGFloat)cellHeightForIssue:(Issue *)issue;

- (void)prepareForReuse;

@property (nonatomic, assign) CompactIssueDateType dateType;

@end

@interface CompactIssueRowView : NSTableRowView

@property (weak, readonly) CompactIssueCellViewController *controller;

@end

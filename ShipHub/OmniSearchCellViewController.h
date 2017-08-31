//
//  OmniSearchCellViewController.h
//  ShipHub
//
//  Created by James Howard on 8/31/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class OmniSearchItem;

@interface OmniSearchCellViewController : NSViewController

@property (nonatomic, strong) OmniSearchItem *item;

@property (nonatomic, readonly) NSTableCellView *cellView;

@end

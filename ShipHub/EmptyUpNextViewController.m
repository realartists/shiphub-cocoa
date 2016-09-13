//
//  EmptyUpNextViewController.m
//  ShipHub
//
//  Created by James Howard on 7/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "EmptyUpNextViewController.h"

#import "Extras.h"
#import "EmptyLabelView.h"

@interface EmptyUpNextViewController ()

@end

@implementation EmptyUpNextViewController

- (void)loadView {
    EmptyLabelView *v = [EmptyLabelView new];
    v.stringValue = NSLocalizedString(@"To add Issues to your Up Next queue, drag them here or use the Add to Up Next menu item", nil);
    self.view = v;
}

@end

//
//  HiddenMilestoneViewController.m
//  ShipHub
//
//  Created by James Howard on 9/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "HiddenMilestoneViewController.h"
#import "OverviewController.h"

@interface HiddenMilestoneViewController ()

@end

@implementation HiddenMilestoneViewController

- (NSString *)nibName { return @"HiddenMilestoneViewController"; }

- (NSSize)preferredMinimumSize {
    return NSMakeSize(480.0, 272.0);
}

- (IBAction)unhideMilestone:(id)sender {
    OverviewController *oc = (id)(self.view.window.delegate);
    [oc unhideItem:sender];
}

@end

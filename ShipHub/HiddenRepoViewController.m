//
//  HiddenRepoViewController.m
//  ShipHub
//
//  Created by James Howard on 9/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "HiddenRepoViewController.h"
#import "OverviewController.h"

@interface HiddenRepoViewController ()

@end

@implementation HiddenRepoViewController

- (NSString *)nibName { return @"HiddenRepoViewController"; }

- (NSSize)preferredMinimumSize {
    return NSMakeSize(480.0, 272.0);
}

- (IBAction)unhideRepo:(id)sender {
    OverviewController *oc = (id)(self.view.window.delegate);
    [oc unhideItem:sender];
}

@end

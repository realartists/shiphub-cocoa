//
//  UnsubscribedRepoController.m
//  ShipHub
//
//  Created by James Howard on 9/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "UnsubscribedRepoController.h"

#import "AppDelegate.h"

@interface UnsubscribedRepoController ()

@end

@implementation UnsubscribedRepoController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)showBilling:(id)sender {
    [[AppDelegate sharedDelegate] showBilling:sender];
}

- (NSSize)preferredMinimumSize {
    return NSMakeSize(480.0, 272.0);
}

@end

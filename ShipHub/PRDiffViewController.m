//
//  PRDiffViewController.m
//  ShipHub
//
//  Created by James Howard on 10/13/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "PRDiffViewController.h"
#import "IssueWebControllerInternal.h"

#import <WebKit/WebKit.h>

@interface PRDiffViewController ()


@end

@implementation PRDiffViewController

- (NSInteger)webpackDevServerPort {
    return 8081;
}

- (NSString *)webResourcePath {
    return @"DiffWeb";
}

@end

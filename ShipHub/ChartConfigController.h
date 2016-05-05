//
//  ChartConfigController.h
//  Ship
//
//  Created by James Howard on 8/14/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ChartConfig.h"

@protocol ChartConfigControllerDelegate;

@interface ChartConfigController : NSViewController

@property (nonatomic, copy) ChartConfig *chartConfig;

@property (weak) id<ChartConfigControllerDelegate> delegate;

- (void)prepare;
- (void)save;

@end

@protocol ChartConfigControllerDelegate <NSObject>

- (void)chartConfigController:(ChartConfigController *)controller configChanged:(ChartConfig *)config;

- (void)chartConfigControllerDismiss:(ChartConfigController *)controller;

@end

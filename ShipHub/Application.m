//
//  Application.m
//  ShipHub
//
//  Created by James Howard on 6/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "Application.h"

#import "Analytics.h"

@implementation Application

- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender {
    if (action == @selector(print:)) {
        [[Analytics sharedInstance] track:@"Print"];
    }
    return [super sendAction:action to:target from:sender];
}

- (void)_crashOnException:(NSException *)e {
    ErrLog(@"%@", e);
    [self reportException:e];
    abort();
}

@end

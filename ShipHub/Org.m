//
//  Org.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Org.h"
#import "LocalOrg.h"

@implementation Org

- (instancetype)initWithLocalItem:(LocalOrg *)localItem {
    if (self = [super initWithLocalItem:localItem]) {
        _shipNeedsWebhookHelp = [localItem.shipNeedsWebhookHelp boolValue];
    }
    return self;
}

@end

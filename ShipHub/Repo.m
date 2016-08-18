//
//  Repo.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "Repo.h"

#import "LocalRepo.h"

@implementation Repo

- (instancetype)initWithLocalItem:(id)localItem {
    LocalRepo *lr = localItem;
    if (self = [super initWithLocalItem:localItem]) {
        _fullName = lr.fullName;
        _hidden = lr.hidden != nil;
        _name = lr.name;
        _private = [lr.private boolValue];
        _shipNeedsWebhookHelp = [lr.shipNeedsWebhookHelp boolValue];
        
    }
    return self;
}

- (BOOL)hasIssues {
    return YES;
}

@end

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

- (id)initWithLocalItem:(id)localItem {
    NSAssert(NO, @"Use initWithLocalItem:owner: instead");
    return nil;
}

- (id)initWithLocalItem:(id)localItem owner:(Account *)owner {
    LocalRepo *lr = localItem;
    if (self = [super initWithLocalItem:localItem]) {
        _fullName = lr.fullName;
        _hidden = lr.hidden != nil;
        _name = lr.name;
        _private = [lr.private boolValue];
        _shipNeedsWebhookHelp = [lr.shipNeedsWebhookHelp boolValue];
        _owner = owner;
    }
    return self;
}

- (BOOL)hasIssues {
    return YES;
}

@end

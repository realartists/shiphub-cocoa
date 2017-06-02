//
//  Repo.h
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "MetadataItem.h"
#import "Billing.h"

@class Account;

@interface Repo : MetadataItem

- (id)initWithLocalItem:(id)localItem NS_UNAVAILABLE;
- (id)initWithLocalItem:(id)localItem owner:(Account *)owner billingState:(BillingState)billingState;

@property (readonly) NSString *fullName;
@property (readonly) NSString *name;
@property (readonly) NSString *issueTemplate;
@property (readonly) NSString *pullRequestTemplate;
@property (readonly, getter=isPrivate) BOOL private;
@property (readonly) BOOL hasIssues;
@property (readonly, getter=isHidden) BOOL hidden;
@property (readonly, getter=isRestricted) BOOL restricted; // if restricted by billing mode

@property (readonly) BOOL shipNeedsWebhookHelp;

@property (readonly) NSString *repoDescription;

@property (readonly) Account *owner;

@end

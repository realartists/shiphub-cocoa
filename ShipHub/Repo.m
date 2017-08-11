//
//  Repo.m
//  ShipHub
//
//  Created by James Howard on 3/21/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "RepoInternal.h"

#import "Auth.h"
#import "Account.h"
#import "AppAdapter.h"

#if TARGET_SHIP
#import "LocalRepo.h"
#endif

@interface Repo ()

@property (readwrite) NSString *fullName;
@property (readwrite) NSString *name;
@property (readwrite) NSString *issueTemplate;
@property (readwrite) NSString *pullRequestTemplate;
@property (readwrite, getter=isPrivate) BOOL private;
@property (readwrite) BOOL hasIssues;
@property (readwrite, getter=isHidden) BOOL hidden;
@property (readwrite, getter=isRestricted) BOOL restricted;

@property (readwrite) NSString *repoDescription;

@property (readwrite) Account *owner;

@property (readwrite) BOOL canPush;

@end

@implementation Repo

#if TARGET_SHIP
- (id)initWithLocalItem:(id)localItem {
    NSAssert(NO, @"Use initWithLocalItem:owner: instead");
    return nil;
}

- (id)initWithLocalItem:(id)localItem owner:(Account *)owner billingState:(BillingState)billingState canPush:(BOOL)canPush {
    LocalRepo *lr = localItem;
    if (self = [super initWithLocalItem:localItem]) {
        _fullName = lr.fullName;
        _hidden = lr.hidden != nil;
        _name = lr.name;
        _issueTemplate = lr.issueTemplate;
        _pullRequestTemplate = lr.pullRequestTemplate;
        _private = [lr.private boolValue];
        _shipNeedsWebhookHelp = canPush && [lr.shipNeedsWebhookHelp boolValue];
        _owner = owner;
        _restricted = _private && billingState == BillingStateFree;
        _hasIssues = [lr.hasIssues boolValue];
        _canPush = canPush;
    }
    return self;
}
#endif

- (instancetype)initWithDictionary:(NSDictionary *)d {
    if (self = [super initWithDictionary:d]) {
        _fullName = d[@"full_name"];
        _name = d[@"name"];
        _private = [d[@"private"] boolValue];
        _owner = [[Account alloc] initWithDictionary:d[@"owner"]];
        _hasIssues = [d[@"has_issues"] boolValue];
        _canPush = [d[@"permissions"][@"push"] boolValue];
    }
    return self;
}

- (NSURL *)URL {
    Auth *auth = [SharedAppAdapter() auth];
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://%@/%@", auth.account.webGHHost, self.fullName]];
}

@end

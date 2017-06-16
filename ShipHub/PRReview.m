//
//  PRReview.m
//  ShipHub
//
//  Created by James Howard on 2/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRReview.h"

#import "Account.h"
#import "Extras.h"
#import "MetadataStore.h"
#import "PRComment.h"
#import "LocalAccount.h"
#import "LocalPRReview.h"
#import "LocalPRComment.h"

@implementation PRReview

- (id)init {
    if (self = [super init]) {
        _user = [Account me];
        _createdAt = [NSDate date];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)d comments:(NSArray<PRComment *> *)comments metadataStore:(MetadataStore *)store {
    if (self = [super init]) {
        _identifier = d[@"id"];
        _user = [store accountWithIdentifier:d[@"user"][@"id"]];
        _body = d[@"body"];
        _state = PRReviewStateFromString(d[@"state"]);
        _createdAt = [NSDate dateWithJSONString:d[@"created_at"]];
        _submittedAt = [NSDate dateWithJSONString:d[@"submitted_at"]];
        _commitId = d[@"commit_id"];
        _comments = [comments copy];
    }
    return self;
}

- (id)initWithLocalReview:(LocalPRReview *)lprr metadataStore:(MetadataStore *)store {
    if (self = [super init]) {
        _identifier  = lprr.identifier;
        _user = [store objectWithManagedObject:lprr.user];
        _body = lprr.body;
        _state = PRReviewStateFromString(lprr.state);
        _createdAt = lprr.createdAt;
        _submittedAt = lprr.submittedAt;
        _commitId = lprr.commitId;
        _comments = [[[lprr.comments allObjects] arrayByMappingObjects:^id(LocalPRComment *lc) {
            return [[PRComment alloc] initWithLocalPRComment:lc metadataStore:store];
        }] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    PRReview *copy = [[PRReview allocWithZone:zone] init];
    copy->_identifier = _identifier;
    copy->_user = _user;
    copy->_body = [_body copy];
    copy->_state = _state;
    copy->_comments = [_comments copy];
    copy->_createdAt = [NSDate date];
    copy->_submittedAt = _submittedAt;
    return copy;
}

@end

PRReviewState PRReviewStateFromEventString(NSString *str) {
    str = [str uppercaseString]; // github is not consistent in its casing. :(
    if ([str isEqualToString:@"APPROVE"]) {
        return PRReviewStateApprove;
    } else if ([str isEqualToString:@"REQUEST_CHANGES"]) {
        return PRReviewStateRequestChanges;
    } else if ([str isEqualToString:@"COMMENT"]) {
        return PRReviewStateComment;
    } else if ([str isEqualToString:@"DISMISS"]) {
        return PRReviewStateDismiss;
    } else {
        return PRReviewStatePending;
    }
}

NSString *PRReviewStateToEventString(PRReviewState st) {
    switch (st) {
        case PRReviewStatePending: return @"PENDING";
        case PRReviewStateApprove: return @"APPROVE";
        case PRReviewStateRequestChanges: return @"REQUEST_CHANGES";
        case PRReviewStateComment: return @"COMMENT";
        case PRReviewStateDismiss: return @"DISMISS";
    }
}

PRReviewState PRReviewStateFromString(NSString *str) {
    str = [str uppercaseString]; // github is not consistent in its casing. :(
    if ([str isEqualToString:@"APPROVED"]) {
        return PRReviewStateApprove;
    } else if ([str isEqualToString:@"CHANGES_REQUESTED"]) {
        return PRReviewStateRequestChanges;
    } else if ([str isEqualToString:@"COMMENTED"]) {
        return PRReviewStateComment;
    } else if ([str isEqualToString:@"DISMISSED"]) {
        return PRReviewStateDismiss;
    } else {
        return PRReviewStatePending;
    }
}

NSString *PRReviewStateToString(PRReviewState st) {
    switch (st) {
        case PRReviewStatePending: return @"PENDING";
        case PRReviewStateApprove: return @"APPROVED";
        case PRReviewStateRequestChanges: return @"CHANGES_REQUESTED";
        case PRReviewStateComment: return @"COMMENTED";
        case PRReviewStateDismiss: return @"DISMISSED";
    }
}

NSString *const PRReviewDeletedExplicitlyNotification = @"PRReviewDeletedExplicitlyNotification";
NSString *const PRReviewDeletedInIssueIdentifierKey = @"PRReviewDeletedInIssueIdentifierKey";

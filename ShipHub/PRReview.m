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
        _status = PRReviewStatusFromString(d[@"status"]);
        _createdAt = [NSDate dateWithJSONString:d[@"created_at"]];
        _commitId = d[@"commit_id"];
        _comments = [comments copy];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    PRReview *copy = [[PRReview allocWithZone:zone] init];
    copy->_identifier = _identifier;
    copy->_user = _user;
    copy->_body = [_body copy];
    copy->_status = _status;
    copy->_comments = [_comments copy];
    copy->_createdAt = [NSDate date];
    return copy;
}

@end

PRReviewStatus PRReviewStatusFromString(NSString *str) {
    if ([str isEqualToString:@"APPROVE"]) {
        return PRReviewStatusApprove;
    } else if ([str isEqualToString:@"REQUEST_CHANGES"]) {
        return PRReviewStatusRequestChanges;
    } else if ([str isEqualToString:@"COMMENT"]) {
        return PRReviewStatusComment;
    } else {
        return PRReviewStatusPending;
    }
}

NSString *PRReviewStatusToString(PRReviewStatus st) {
    switch (st) {
        case PRReviewStatusPending: return @"PENDING";
        case PRReviewStatusApprove: return @"APPROVE";
        case PRReviewStatusRequestChanges: return @"REQUEST_CHANGES";
        case PRReviewStatusComment: return @"COMMENT";
    }
}

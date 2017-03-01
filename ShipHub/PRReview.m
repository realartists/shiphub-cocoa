//
//  PRReview.m
//  ShipHub
//
//  Created by James Howard on 2/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRReview.h"

@implementation PRReview

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

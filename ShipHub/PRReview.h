//
//  PRReview.h
//  ShipHub
//
//  Created by James Howard on 2/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PRComment;

typedef NS_ENUM(NSInteger, PRReviewStatus) {
    PRReviewStatusPending = 0,
    PRReviewStatusApprove,
    PRReviewStatusRequestChanges,
    PRReviewStatusComment,
};

extern PRReviewStatus PRReviewStatusFromString(NSString *str);
extern NSString *PRReviewStatusToString(PRReviewStatus st);

@interface PRReview : NSObject

@property PRReviewStatus status;
@property NSString *body;
@property NSArray<PRComment *> *comments;

@end

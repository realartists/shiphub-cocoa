//
//  PRReview.h
//  ShipHub
//
//  Created by James Howard on 2/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Account;
@class PRComment;
@class MetadataStore;

typedef NS_ENUM(NSInteger, PRReviewStatus) {
    PRReviewStatusPending = 0,
    PRReviewStatusApprove,
    PRReviewStatusRequestChanges,
    PRReviewStatusComment,
};

extern PRReviewStatus PRReviewStatusFromString(NSString *str);
extern NSString *PRReviewStatusToString(PRReviewStatus st);

@interface PRReview : NSObject <NSCopying>

- (id)init;
- (id)initWithDictionary:(NSDictionary *)d comments:(NSArray<PRComment *> *)comments metadataStore:(MetadataStore *)store;

@property NSNumber *identifier;
@property Account *user;
@property PRReviewStatus status;
@property NSString *body;
@property NSArray<PRComment *> *comments;

@end

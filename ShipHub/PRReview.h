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

#if TARGET_SHIP
@class MetadataStore;
@class LocalPRReview;
#endif


typedef NS_ENUM(NSInteger, PRReviewState) {
    PRReviewStatePending = 0,
    PRReviewStateApprove,
    PRReviewStateRequestChanges,
    PRReviewStateComment,
    PRReviewStateDismiss
};

extern PRReviewState PRReviewStateFromEventString(NSString *str);
extern NSString *PRReviewStateToEventString(PRReviewState st);

extern PRReviewState PRReviewStateFromString(NSString *str);
extern NSString *PRReviewStateToString(PRReviewState st);

@interface PRReview : NSObject <NSCopying>

- (id)init;

#if TARGET_SHIP
- (id)initWithDictionary:(NSDictionary *)d comments:(NSArray<PRComment *> *)comments metadataStore:(MetadataStore *)store;
- (id)initWithLocalReview:(LocalPRReview *)lprr metadataStore:(MetadataStore *)store;
#endif

@property NSNumber *identifier;
@property Account *user;
@property PRReviewState state;
@property NSString *body;
@property NSDate *createdAt;
@property NSDate *submittedAt;
@property NSString *commitId;
@property NSArray<PRComment *> *comments;

@property BOOL shipReviewPreventsAddingReplies;

@end

extern NSString *const PRReviewDeletedExplicitlyNotification;
extern NSString *const PRReviewDeletedInIssueIdentifierKey;

extern NSString *const PRReviewEditedCommentExplicitlyNotification;
extern NSString *const PRReviewEditedCommentKey; // => PRComment

extern NSString *const PRReviewDeletedCommentExplicitlyNotification;
extern NSString *const PRReviewDeletedCommentKey; // => PRComment

extern BOOL PendingReviewIdentifierIsLocal(NSNumber *reviewID);

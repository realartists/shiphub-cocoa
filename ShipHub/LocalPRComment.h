//
//  LocalPRComment.h
//  ShipHub
//
//  Created by James Howard on 4/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@class LocalAccount, LocalIssue, LocalPRReview, LocalReaction;

@interface LocalPRComment : NSManagedObject

@property (nonatomic, strong) NSString *diffHunk;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSNumber *position;
@property (nonatomic, strong) NSNumber *originalPosition;
@property (nonatomic, strong) NSString *commitId;
@property (nonatomic, strong) NSString *originalCommitId;
@property (nonatomic, strong) NSNumber *inReplyTo;

@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSNumber *identifier;
@property (nonatomic, strong) NSDate *updatedAt;

@property (nonatomic, strong) LocalAccount *user;
@property (nonatomic, strong) LocalIssue *issue;
@property (nonatomic, strong) LocalPRReview *review;

@property (nonatomic, strong) NSSet <LocalReaction *> *reactions;

@end

@interface LocalPRComment (CoreDataAccessors)

- (void)addReactionsObject:(LocalReaction *)value;
- (void)removeReactionsObject:(LocalReaction *)value;
- (void)addReactions:(NSSet<LocalReaction *> *)values;
- (void)removeReactions:(NSSet<LocalReaction *> *)values;

@end

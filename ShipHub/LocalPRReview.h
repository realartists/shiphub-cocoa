//
//  LocalPRReview.h
//  ShipHub
//
//  Created by James Howard on 4/18/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@class LocalAccount, LocalIssue, LocalPRComment;

@interface LocalPRReview : NSManagedObject

@property (nonatomic, strong) NSNumber *identifier;
@property (nonatomic, strong) NSString *state;
@property (nonatomic, strong) NSString *body;
@property (nonatomic, strong) NSDate *createdAt;
@property (nonatomic, strong) NSDate *submittedAt;
@property (nonatomic, strong) NSString *commitId;

@property (nonatomic, strong) LocalIssue *issue;
@property (nonatomic, strong) LocalAccount *user;

@property (nonatomic, strong) NSSet<LocalPRComment *> *comments;

@end

@interface LocalPRReview (CoreDataAccessors)

- (void)addCommentsObject:(LocalPRComment *)value;
- (void)removeCommentsObject:(LocalPRComment *)value;
- (void)addComments:(NSSet<LocalPRComment *> *)values;
- (void)removeReactions:(NSSet<LocalPRComment *> *)values;

@end

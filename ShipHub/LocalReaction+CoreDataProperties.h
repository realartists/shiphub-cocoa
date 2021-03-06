//
//  LocalReaction+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 8/3/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalReaction.h"

@class LocalAccount;
@class LocalPRComment;
@class LocalCommitComment;

NS_ASSUME_NONNULL_BEGIN

@interface LocalReaction (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSString *content;
@property (nullable, nonatomic, retain) NSDate *createdAt;
@property (nullable, nonatomic, retain) LocalAccount *user;
@property (nullable, nonatomic, retain) LocalIssue *issue;
@property (nullable, nonatomic, retain) LocalComment *comment;
@property (nullable, nonatomic, retain) LocalPRComment *prComment;
@property (nullable, nonatomic, retain) LocalCommitComment *commitComment;

@end

NS_ASSUME_NONNULL_END

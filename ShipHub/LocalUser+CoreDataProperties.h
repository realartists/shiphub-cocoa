//
//  LocalUser+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalUser.h"

@class LocalComment;
@class LocalOrg;

NS_ASSUME_NONNULL_BEGIN

@interface LocalUser (CoreDataProperties)

@property (nullable, nonatomic, retain) NSSet<LocalEvent *> *actedEvents;
@property (nullable, nonatomic, retain) NSSet<LocalRepo *> *assignable;
@property (nullable, nonatomic, retain) NSSet<LocalEvent *> *assignedEvents;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *assignedIssues;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *closedIssues;
@property (nullable, nonatomic, retain) NSSet<LocalComment *> *comments;
@property (nullable, nonatomic, retain) NSSet<LocalOrg *> *orgs;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *originatedIssues;

@end

@interface LocalUser (CoreDataGeneratedAccessors)

- (void)addActedEventsObject:(LocalEvent *)value;
- (void)removeActedEventsObject:(LocalEvent *)value;
- (void)addActedEvents:(NSSet<LocalEvent *> *)values;
- (void)removeActedEvents:(NSSet<LocalEvent *> *)values;

- (void)addAssignableObject:(LocalRepo *)value;
- (void)removeAssignableObject:(LocalRepo *)value;
- (void)addAssignable:(NSSet<LocalRepo *> *)values;
- (void)removeAssignable:(NSSet<LocalRepo *> *)values;

- (void)addAssignedEventsObject:(LocalEvent *)value;
- (void)removeAssignedEventsObject:(LocalEvent *)value;
- (void)addAssignedEvents:(NSSet<LocalEvent *> *)values;
- (void)removeAssignedEvents:(NSSet<LocalEvent *> *)values;

- (void)addAssignedIssuesObject:(LocalIssue *)value;
- (void)removeAssignedIssuesObject:(LocalIssue *)value;
- (void)addAssignedIssues:(NSSet<LocalIssue *> *)values;
- (void)removeAssignedIssues:(NSSet<LocalIssue *> *)values;

- (void)addClosedIssuesObject:(LocalIssue *)value;
- (void)removeClosedIssuesObject:(LocalIssue *)value;
- (void)addClosedIssues:(NSSet<LocalIssue *> *)values;
- (void)removeClosedIssues:(NSSet<LocalIssue *> *)values;

- (void)addCommentsObject:(LocalComment *)value;
- (void)removeCommentsObject:(LocalComment *)value;
- (void)addComments:(NSSet<LocalComment *> *)values;
- (void)removeComments:(NSSet<LocalComment *> *)values;

- (void)addOrgsObject:(LocalOrg *)value;
- (void)removeOrgsObject:(LocalOrg *)value;
- (void)addOrgs:(NSSet<LocalOrg *> *)values;
- (void)removeOrgs:(NSSet<LocalOrg *> *)values;

- (void)addOriginatedIssuesObject:(LocalIssue *)value;
- (void)removeOriginatedIssuesObject:(LocalIssue *)value;
- (void)addOriginatedIssues:(NSSet<LocalIssue *> *)values;
- (void)removeOriginatedIssues:(NSSet<LocalIssue *> *)values;

@end

NS_ASSUME_NONNULL_END

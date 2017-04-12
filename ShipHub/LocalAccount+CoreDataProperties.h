//
//  LocalAccount+CoreDataProperties.h
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "LocalAccount.h"

@class LocalEvent;
@class LocalComment;
@class LocalReaction;
@class LocalProject;
@class LocalIssue;

NS_ASSUME_NONNULL_BEGIN

@interface LocalAccount (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *avatarURL;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSString *login;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSString *type;
@property (nullable, nonatomic, retain) NSSet<LocalRepo *> *repos;

@property (nullable, nonatomic, retain) NSSet<LocalEvent *> *actedEvents;
@property (nullable, nonatomic, retain) NSSet<LocalRepo *> *assignable;
@property (nullable, nonatomic, retain) NSSet<LocalEvent *> *assignedEvents;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *assignedIssues;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *closedIssues;
@property (nullable, nonatomic, retain) NSSet<LocalComment *> *comments;
@property (nullable, nonatomic, retain) NSSet<LocalAccount *> *orgs;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *originatedIssues;
@property (nullable, nonatomic, retain) NSSet<LocalReaction *> *reactions;
@property (nullable, nonatomic, retain) NSSet<LocalProject *> *createdProjects;
@property (nullable, nonatomic, retain) NSSet<LocalIssue *> *reviewRequests;

@property (nullable, nonatomic, retain) NSNumber *shipNeedsWebhookHelp;
@property (nullable, nonatomic, retain) NSSet<LocalAccount *> *users;
@property (nullable, nonatomic, retain) NSSet<LocalProject *> *projects;

@end

@interface LocalAccount (CoreDataGeneratedAccessors)

- (void)addReposObject:(LocalRepo *)value;
- (void)removeReposObject:(LocalRepo *)value;
- (void)addRepos:(NSSet<LocalRepo *> *)values;
- (void)removeRepos:(NSSet<LocalRepo *> *)values;

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

- (void)addOrgsObject:(LocalAccount *)value;
- (void)removeOrgsObject:(LocalAccount *)value;
- (void)addOrgs:(NSSet<LocalAccount *> *)values;
- (void)removeOrgs:(NSSet<LocalAccount *> *)values;

- (void)addOriginatedIssuesObject:(LocalIssue *)value;
- (void)removeOriginatedIssuesObject:(LocalIssue *)value;
- (void)addOriginatedIssues:(NSSet<LocalIssue *> *)values;
- (void)removeOriginatedIssues:(NSSet<LocalIssue *> *)values;

- (void)addReactionsObject:(LocalReaction *)value;
- (void)removeReactionsObject:(LocalReaction *)value;
- (void)addReactions:(NSSet<LocalReaction *> *)values;
- (void)removeReactions:(NSSet<LocalReaction *> *)values;

- (void)addCreatedProjectsObject:(LocalProject *)value;
- (void)removeCreatedProjectsObject:(LocalProject *)value;
- (void)addCreatedProjects:(NSSet<LocalProject *> *)values;
- (void)removeCreatedProjects:(NSSet<LocalProject *> *)values;

- (void)addUsersObject:(LocalAccount *)value;
- (void)removeUsersObject:(LocalAccount *)value;
- (void)addUsers:(NSSet<LocalAccount *> *)values;
- (void)removeUsers:(NSSet<LocalAccount *> *)values;

- (void)addProjectsObject:(LocalProject *)value;
- (void)removeProjectsObject:(LocalProject *)value;
- (void)addProjects:(NSSet<LocalProject *> *)values;
- (void)removeProjects:(NSSet<LocalProject *> *)values;

- (void)addReviewRequestsObject:(LocalIssue *)value;
- (void)removeReviewRequestsObject:(LocalIssue *)value;
- (void)addReviewRequests:(NSSet<LocalIssue *> *)values;
- (void)removeReviewRequests:(NSSet<LocalIssue *> *)values;

@end

NS_ASSUME_NONNULL_END

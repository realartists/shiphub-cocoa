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

NS_ASSUME_NONNULL_BEGIN

@interface LocalAccount (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *avatarURL;
@property (nullable, nonatomic, retain) NSNumber *identifier;
@property (nullable, nonatomic, retain) NSString *login;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSSet<LocalRepo *> *repos;

@end

@interface LocalAccount (CoreDataGeneratedAccessors)

- (void)addReposObject:(LocalRepo *)value;
- (void)removeReposObject:(LocalRepo *)value;
- (void)addRepos:(NSSet<LocalRepo *> *)values;
- (void)removeRepos:(NSSet<LocalRepo *> *)values;

@end

NS_ASSUME_NONNULL_END

//
//  RMERepo.h
//  Reviewed By Me
//
//  Created by James Howard on 12/6/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "Repo.h"

@class Account;

@interface RMERepo : Repo

- (id)initWithGraphQL:(NSDictionary *)gql;

@property (readonly) NSString *defaultBranch;
@property (readonly) NSArray<Account *> *assignable;

@end

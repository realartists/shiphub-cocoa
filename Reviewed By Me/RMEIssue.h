//
//  RMEIssue.h
//  Reviewed By Me
//
//  Created by James Howard on 12/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "Issue.h"

@interface RMEIssue : Issue

- (id)initWithGraphQL:(NSDictionary *)gql repository:(Repo *)repo;

@end

//
//  RMERepo.m
//  Reviewed By Me
//
//  Created by James Howard on 12/6/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMERepo.h"

#import "Extras.h"
#import "RepoInternal.h"
#import "RMEAccount.h"

@interface RMERepo ()

@property (readwrite) NSString *defaultBranch;
@property (readwrite) NSArray *assignable;

@end

@implementation RMERepo

- (id)initWithGraphQL:(NSDictionary *)gql {
    if (self = [super init]) {
        self.identifier = gql[@"databaseId"];
        self.name = gql[@"name"];
        self.fullName = gql[@"nameWithOwner"];
        self.private = [gql[@"isPrivate"] boolValue];
        self.defaultBranch = gql[@"defaultBranchRef"][@"name"];
        self.owner = [[RMEAccount alloc] initWithGraphQL:gql[@"owner"]];
        
        self.assignable = [[gql valueForKeyPath:@"assignableUsers.edges.node"] arrayByMappingObjects:^id(id obj) {
            return [[RMEAccount alloc] initWithGraphQL:obj];
        }];
    }
    return self;
}

@end

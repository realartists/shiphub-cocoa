//
//  RMEAccount.m
//  Reviewed By Me
//
//  Created by James Howard on 12/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEAccount.h"
#import "AccountInternal.h"

@implementation RMEAccount

- (id)initWithGraphQL:(NSDictionary *)d {
    if (!d) return nil;
    
    if (self = [super init]) {
        self.identifier = d[@"databaseId"];
        self.login = d[@"login"];
        self.name = d[@"name"];
        NSString *typename = d[@"__typename"] ?: @"User";
        if ([typename isEqualToString:@"User"]) {
            self.accountType = AccountTypeUser;
        } else if ([typename isEqualToString:@"Organization"]) {
            self.accountType = AccountTypeOrg;
        }
    }
    return self;
}

@end

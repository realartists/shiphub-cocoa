//
//  UserRowTemplate.m
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "UserRowTemplate.h"
#import "CompletingTextField.h"

#import "DataStore.h"
#import "MetadataStore.h"
#import "Account.h"

#import "Extras.h"

@implementation UserRowTemplate

- (NSArray *)complete:(NSString *)text {
    NSArray *logins = [[[[DataStore activeStore] metadataStore] allAssignees] arrayByMappingObjects:^id(id obj) {
        return [obj login];
    }];
    if ([text length] == 0) {
        return logins;
    } else {
        return [logins filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF contains[cd] %@", text]];
    }
}

- (NSString *)valueWithIdentifier:(NSString *)identifier {
    return identifier;
}

- (NSString *)identifierWithValue:(NSString *)value {
    return [value length] > 0 ? value : nil;
}

@end

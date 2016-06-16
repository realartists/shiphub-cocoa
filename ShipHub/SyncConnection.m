//
//  SyncConnection.m
//  ShipHub
//
//  Created by James Howard on 3/8/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "SyncConnection.h"

#import "Auth.h"

@interface SyncConnection ()

@property (strong) Auth *auth;

@end

@implementation SyncConnection

- (id)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        self.auth = auth;
    }
    return self;
}

- (void)syncWithVersions:(NSDictionary *)versions {
    
}

- (void)updateIssue:(id)issueIdentifier {
    
}

@end

@implementation SyncEntry

+ (instancetype)entryWithDictionary:(NSDictionary *)dict {
    SyncEntry *e = [[self class] new];
    e.action = [dict[@"action"] isEqualToString:@"set"] ? SyncEntryActionSet : SyncEntryActionDelete;
    e.entityName = dict[@"entity"];
    e.data = dict[@"data"];
    return e;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"{%s %@} : %@", _action == SyncEntryActionSet ? "set" : "del", _entityName, _data];
}

@end

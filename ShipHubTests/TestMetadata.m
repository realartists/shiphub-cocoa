//
//  TestMetadata.m
//  Ship
//
//  Created by James Howard on 6/22/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "TestMetadata.h"

#import "Extras.h"

@implementation TestMetadata

+ (NSArray *)ids:(NSArray *)a {
    return [a arrayByMappingObjects:^id(id obj) {
        return [obj objectForKey:@"identifier"];
    }];
}

+ (NSDictionary *)roots {
    return
    @{ @"users": [self ids:[self users]],
       @"orgs": [self ids:[self orgs]]
       };
}

+ (NSArray *)users {
    return
    @[ @{ @"identifier" : @1,
          @"login" : @"james-howard",
          @"name" : @"James Howard",
          @"repos" : @[@1] },
       
       @{ @"identifier" : @2,
          @"login" : @"kogir",
          @"name" : @"Nick Sivo" },
    ];
}

+ (NSArray *)orgs {
    return
    @[ @{ @"identifier": @1,
          @"login" : @"realartists",
          @"name" : @"Real Artists, Inc",
          @"repos" : [self ids:[self repos]] }
    ];
}

+ (NSArray *)repos {
    return
    @[ @{ @"fullName": @"testorg/testrepo",
          @"name" : @"testrepo",
          @"identifier" : @1,
          @"private" : @YES,
          @"repoDescription" : @"A Test Repo",
          
          @"assignees" : [self ids:[self users]],
          @"labels" : [self labels],
          @"milestones": [self ids:[self milestones]],
          @"owner" : [self users][0] },
    ];
}

+ (NSArray *)labels {
    return
    @[ @{ @"color" : @"ff0000",
          @"name" : @"red" },
       @{ @"color" : @"00ff00",
          @"name" : @"green" }
    ];
}

+ (NSArray *)milestones {
    return
    @[ @{ @"identifier" : @1,
          @"title" : @"v1.0" },
       @{ @"identifier" : @2,
          @"title" : @"v2.0" }];
}

@end

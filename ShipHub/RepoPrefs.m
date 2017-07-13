//
//  RepoPrefs.m
//  ShipHub
//
//  Created by James Howard on 7/11/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RepoPrefs.h"

#import "Extras.h"

@implementation RepoPrefs

- (id)initWithDictionary:(NSDictionary *)d {
    if (self = [super init]) {
        _whitelist = d[@"include"] ?: @[];
        _blacklist = d[@"exclude"] ?: @[];
        NSNumber *autotrack = d[@"autoTrack"];
        _autotrack = autotrack ? [autotrack boolValue] : YES;
    }
    return self;
}

- (NSMutableDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary new];
    [d setOptional:_whitelist forKey:@"include"];
    [d setOptional:_blacklist forKey:@"exclude"];
    d[@"autoTrack"] = @(_autotrack);
    return d;
}

@end

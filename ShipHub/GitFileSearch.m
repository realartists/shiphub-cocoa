//
//  GitFileSearch.m
//  ShipHub
//
//  Created by James Howard on 6/7/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "GitFileSearch.h"

@implementation GitFileSearch

- (id)copyWithZone:(NSZone *)zone {
    GitFileSearch *copy = [GitFileSearch new];
    copy.query = _query;
    copy.flags = _flags;
    return copy;
}

@end

@implementation GitFileSearchResult

@end

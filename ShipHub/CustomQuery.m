//
//  CustomQuery.m
//  Ship
//
//  Created by James Howard on 7/28/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "CustomQuery.h"
#import "Extras.h"
#import "User.h"
#import "LocalUser.h"
#import "LocalQuery.h"

#import "DataStore.h"
#import "MetadataStore.h"

@implementation CustomQuery {
    NSPredicate *_predicate;
    NSString *_predicateStr;
}

- (id)init {
    if (self = [super init]) {
        _authorIdentifier = [[User me] identifier];
        _identifier = [[[NSUUID UUID] UUIDString] lowercaseString];
    }
    return self;
}

- (id)initWithLocalItem:(LocalQuery *)query {
    if (self = [super init]) {
        _identifier = query.identifier;
        _authorIdentifier = query.author.identifier;
        _title = query.title;
        _predicateStr = query.predicate;
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)d {
    if (self = [super init]) {
        _title = d[@"title"];
        _authorIdentifier = d[@"authorIdentifier"];
        _predicateStr = d[@"predicate"];
    }
    return self;
}

- (void)setPredicate:(NSPredicate *)predicate {
    _predicateStr = [predicate description];
    _predicate = predicate;
}

- (NSPredicate *)predicate {
    if (_predicate) {
        return _predicate;
    } else if (_predicateStr) {
        @try {
            _predicate = [NSPredicate predicateWithFormat:_predicateStr];
        } @catch (id exc) {
            _predicateStr = nil;
            _predicate = nil;
            ErrLog(@"Error deserializing predicate %@: %@", _predicateStr, exc);
        }
        return _predicate;
    } else {
        return nil;
    }
}

- (void)setPredicateString:(NSString *)predicateStr {
    _predicateStr = predicateStr;
    _predicate = nil;
}

- (NSString *)predicateString {
    return _predicateStr;
}

- (NSMutableDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    [d setOptional:_title forKey:@"title"];
    d[@"authorIdentifier"] = _authorIdentifier;
    d[@"identifier"] = _identifier;
    [d setOptional:_predicateStr forKey:@"predicate"];
    return d;
}

- (NSURL *)URL {
    NSUUID *UUID = [[NSUUID alloc] initWithUUIDString:[self.identifier uppercaseString]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"ship+github://Query/%@", [UUID shortString]]];
}

- (NSString *)URLAndTitle {
    return [NSString stringWithFormat:@"%@ <%@>", [self URL], _title];
}

- (NSString *)titleWithAuthor {
    NSString *author = [[[[DataStore activeStore] metadataStore] userWithIdentifier:self.authorIdentifier] login];
    if (![self isMine] && author) {
        return [NSString stringWithFormat:NSLocalizedString(@"%@ Shared By %@", @"Custom Query title with author name"), self.title, author];
    } else {
        return self.title;
    }
}

- (BOOL)isMine {
    return [self.authorIdentifier isEqual:[[User me] identifier]];
}

@end

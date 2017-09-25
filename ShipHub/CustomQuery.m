//
//  CustomQuery.m
//  Ship
//
//  Created by James Howard on 7/28/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "CustomQuery.h"
#import "Extras.h"
#import "Account.h"
#import "Auth.h"
#import "LocalAccount.h"
#import "LocalQuery.h"

#import "DataStore.h"
#import "MetadataStore.h"

@implementation CustomQuery {
    NSPredicate *_predicate;
    NSString *_predicateStr;
}

- (id)init {
    if (self = [super init]) {
        _author = [Account me];
        _authorIdentifier = [[Account me] identifier];
        _identifier = [[[NSUUID UUID] UUIDString] lowercaseString];
    }
    return self;
}

- (id)initWithLocalItem:(LocalQuery *)query metadata:(MetadataStore *)ms {
    if (self = [super init]) {
        _identifier = query.identifier;
        _authorIdentifier = query.author.identifier;
        _author = [ms accountWithIdentifier:_authorIdentifier];
        _title = query.title;
        _predicateStr = query.predicate;
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)d {
    if (self = [super init]) {
        _title = d[@"title"];
        _authorIdentifier = d[@"author"];
        _predicateStr = d[@"predicate"];
        _author = [[[DataStore activeStore] metadataStore] accountWithIdentifier:_authorIdentifier];
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
    d[@"author"] = _authorIdentifier;
    d[@"identifier"] = _identifier;
    [d setOptional:_predicateStr forKey:@"predicate"];
    return d;
}

- (NSURL *)URL {
    NSString *host = [[[[DataStore activeStore] auth] account] shipHost];
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = @"ship.realartists.com";
    comps.path = [NSString stringWithFormat:@"/query/%@", self.identifier];
    if (![host isEqualToString:@"ship.realartists.com"]) {
        comps.queryItemsDictionary = @{ @"env" : host };
    }
    return comps.URL;
}

+ (BOOL)isQueryURL:(NSURL *)URL {
    return ([[URL scheme] isEqualToString:@"ship+github"] && [[URL host] isEqualToString:@"query"])
    || ([[URL scheme] isEqualToString:@"https"] && [[URL host] isEqualToString:@"ship.realartists.com"] && [[URL path] hasPrefix:@"/query/"]);
}

+ (NSString *)identifierFromQueryURL:(NSURL *)URL {
    if ([self isQueryURL:URL]) {
        NSString *identifier = [URL lastPathComponent];
        if ([identifier isUUID]) {
            return [identifier lowercaseString];
        }
    }
    return nil;
}

- (NSString *)titleWithAuthor {
    NSString *author = [[[[DataStore activeStore] metadataStore] accountWithIdentifier:self.authorIdentifier] login];
    if (![self isMine] && author) {
        return [NSString stringWithFormat:NSLocalizedString(@"%@ Shared By %@", @"Custom Query title with author name"), self.title, author];
    } else {
        return self.title;
    }
}

- (BOOL)isMine {
    return [self.authorIdentifier isEqual:[[Account me] identifier]];
}

- (CustomQuery *)copyIfNeededForEditing {
    if ([self isMine]) {
        return self;
    } else {
        CustomQuery *q = [CustomQuery new];
        q.title = self.title;
        q.predicate = self.predicate;
        return q;
    }
}

@end

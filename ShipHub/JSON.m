//
//  JSON.m
//  ShipHub
//
//  Created by James Howard on 3/28/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "JSON.h"

#import "Extras.h"

#import <objc/runtime.h>

@implementation JSON

static void enumerateProperties(id obj, void (^block)(NSString *propName)) {
    
    Class root = [NSObject class];
    if (![obj isKindOfClass:root]) {
        return;
    }
    
    Class c = [obj class];
    while (c != root) {
        
        unsigned int count = 0;
        objc_property_t *props = class_copyPropertyList(c, &count);
        
        for (unsigned int i = 0; i < count; i++) {
            NSString *propName = [NSString stringWithUTF8String:property_getName(props[i])];
            if ([propName length] > 0) {
                block(propName);
            }
        }
        
        c = [c superclass];
    }
}

static id serializeProperties(id obj, JSONNameTransformer nt) {
    NSMutableDictionary *d = [NSMutableDictionary new];
    enumerateProperties(obj, ^(NSString *propName) {
        id p = [obj valueForKey:propName];
        if (p) {
            d[nt(propName)] = serializeObject(p, nt);
        }
    });
    return d;
}

#if TARGET_OS_IPHONE
#define UINSColor UIColor
#else
#define UINSColor NSColor
#endif

static id serializeObject(id obj, JSONNameTransformer nt) {
    if ([obj isKindOfClass:[NSArray class]]) {
        return [obj arrayByMappingObjects:^id(id o) {
            return serializeObject(o, nt);
        }];
    } else if ([obj isKindOfClass:[NSSet class]]) {
        return serializeObject([obj allObjects], nt);
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:[obj count]];
        for (NSString *k in obj) {
            d[nt(k)] = serializeObject(obj[k], nt);
        }
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        return obj;
    } else if ([obj isKindOfClass:[NSValue class]]) {
        return [obj description];
    } else if ([obj isKindOfClass:[NSString class]]) {
        return obj;
    } else if ([obj isKindOfClass:[NSDate class]]) {
        return [obj JSONString];
    } else if ([obj isKindOfClass:[NSData class]]) {
        return [obj base64EncodedStringWithOptions:0];
    } else if ([obj isKindOfClass:[NSURL class]]) {
        return [obj description];
    } else if ([obj isKindOfClass:[UINSColor class]]) {
        return [obj hexString];
    } else if (obj == [NSNull null]) {
        return obj;
    } else {
        return serializeProperties(obj, nt);
    }
    return nil;
}

+ (id)stringifyObject:(id)obj {
    return [self stringifyObject:obj withNameTransformer:[self passthroughNameTransformer]];
}

+ (id)stringifyObject:(id)src withNameTransformer:(JSONNameTransformer)nameTransformer {
    id json = serializeObject(src, nameTransformer);
    NSError *err = nil;
    NSData *d = [NSJSONSerialization dataWithJSONObject:json options:0 error:&err];
    if (err) {
        ErrLog(@"%@", err);
        return nil;
    }
    return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
}

+ (JSONNameTransformer)passthroughNameTransformer {
    return ^(NSString *s) { return s; };
}

static NSString *camelsToBars(NSString *s) {
    
    // URLConnection => url_connection
    //      Any multiple caps run leads to a bar before the last char in the run
    
    // camelCase => camel_case
    //      Any lower => upper transition leads to a bar
    
    // foo => foo
    //      All lowercase strings are returned unchanged
    
    
    NSString *lower = [s lowercaseString];
    if ([s isEqualToString:lower]) {
        return s;
    }
    
    NSMutableString *ms = [NSMutableString new];
    NSInteger upperRun = 0;
    
    NSUInteger len = [s length];
    for (NSUInteger i = 0; i < len; i++) {
        unichar c = [s characterAtIndex:i];
        unichar cl = [lower characterAtIndex:i];
        BOOL cup = c != cl;
        
        if (cup) {
            if (i != 0 && upperRun == 0) {
                // time for a bar
                [ms appendString:@"_"];
            }
            upperRun++;
        } else {
            if (upperRun > 1) {
                // need a bar before the last character
                NSCAssert(ms.length >= 2, nil);
                [ms insertString:@"_" atIndex:ms.length-2];
            }
            upperRun = 0;
        }
        
        [ms appendFormat:@"%C", cl];
    }
    
    return ms;
}

+ (JSONNameTransformer)underbarsNameTransformer {
    return ^(NSString *s) {
        return camelsToBars(s);
    };
}

+ (JSONNameTransformer)underbarsAndIDNameTransformer {
    return ^(NSString *s) {
        if ([s isEqualToString:@"identifier"]) {
            return @"id";
        } else {
            return camelsToBars(s);
        }
    };
}

@end

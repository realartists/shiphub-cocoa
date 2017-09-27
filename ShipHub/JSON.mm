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
#import <JavaScriptCore/JavaScriptCore.h>
#import <unordered_set>

typedef std::unordered_set<void *> ObjSet;

@implementation JSON

static BOOL pushCycleObj(id obj, ObjSet &cycleDetector) {
    if (cycleDetector.find((__bridge void *)obj) != cycleDetector.end()) {
        NSCAssert(NO, @"JSON serialization cycle found on object: %@", obj);
        return NO;
    }
    cycleDetector.insert((__bridge void *)obj);
    return YES;
}

static void popCycleObj(id obj, ObjSet &cycleDetector) {
    cycleDetector.erase((__bridge void *)obj);
}

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
        
        free(props);
        
        c = [c superclass];
    }
}

static id serializeProperties(id obj, JSONNameTransformer nt, ObjSet &cycleDetector) {
    NSMutableDictionary *d = [NSMutableDictionary new];
    enumerateProperties(obj, ^(NSString *propName) {
        id p = [obj valueForKey:propName];
        if (p) {
            d[nt(propName)] = serializeObject(p, nt, cycleDetector);
        }
    });
    return d;
}

#if TARGET_OS_IPHONE
#define UINSColor UIColor
#else
#define UINSColor NSColor
#endif

static id withCycleDetector(ObjSet &cycleDetector, id obj, id (^work)()) {
    if (pushCycleObj(obj, cycleDetector)) {
        id ret = work();
        popCycleObj(obj, cycleDetector);
        return ret;
    } else {
        return [NSNull null];
    }
}

static id serializeObject(id obj, JSONNameTransformer nt, ObjSet &cycleDetector) {
    if ([obj isKindOfClass:[NSArray class]]) {
        return withCycleDetector(cycleDetector, obj, ^{
            return [obj arrayByMappingObjects:^id(id o) {
                id v = serializeObject(o, nt, cycleDetector);
                NSCAssert(v != nil, nil);
                return v;
            }];
        });
    } else if ([obj isKindOfClass:[NSSet class]]) {
        return withCycleDetector(cycleDetector, obj, ^id{
            return serializeObject([obj allObjects], nt, cycleDetector);
        });
    } else if ([obj isKindOfClass:[NSDictionary class]]) {
        return withCycleDetector(cycleDetector, obj, ^id{
            NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:[obj count]];
            for (NSString *k in obj) {
                d[nt(k)] = serializeObject(obj[k], nt, cycleDetector);
            }
            return d;
        });
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
    } else if ([obj respondsToSelector:@selector(JSONDescription)]) {
        return withCycleDetector(cycleDetector, obj, ^id{
            return serializeObject([obj JSONDescription], nt, cycleDetector);
        });
    } else if (obj) {
        return withCycleDetector(cycleDetector, obj, ^id{
            return serializeProperties(obj, nt, cycleDetector);
        });
    } else {
        return [NSNull null];
    }
}

static NSString *stringifyJSONObject(id obj) {
    // NSJSONSerialization only takes dictionaries and arrays as top level objects
    // while this is probably correct from a strict JSON point of view, we actually
    // just want interop with Javascript here, so we'll take anything Javascript can parse.
    
    if (!obj || obj == [NSNull null]) {
        return @"null";
    }
    
    if ([NSJSONSerialization isValidJSONObject:obj]) {
        NSError *err = nil;
        NSData *d = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&err];
        if (err) {
            ErrLog(@"%@", err);
            return nil;
        }
        return [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    } else if ([obj isKindOfClass:[NSString class]]) {
        NSArray *a = @[obj];
        NSData *d = [NSJSONSerialization dataWithJSONObject:a options:0 error:NULL];
        NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        NSString *ret = [s substringWithRange:NSMakeRange(1, s.length-2)];
        NSCAssert([ret rangeOfString:@"\r"].location == NSNotFound, @"No newlines!");
        return ret;
    } else if ([obj isKindOfClass:[NSNumber class]]) {
        return [obj description];
    } else {
        ErrLog(@"Cannot stringify %@", obj);
        return nil;
    }
}

+ (id)stringifyObject:(id)obj {
    return [self stringifyObject:obj withNameTransformer:[self passthroughNameTransformer]];
}

+ (id)stringifyObject:(id)src withNameTransformer:(JSONNameTransformer)nameTransformer {
    if (!src) return @"null";
    
    ObjSet cycleDetector;
    id json = serializeObject(src, nameTransformer, cycleDetector);
    return stringifyJSONObject(json);
}

+ (id)serializeObject:(id)src withNameTransformer:(JSONNameTransformer)nameTransformer {
    if (!src) return [NSNull null];
    
    ObjSet cycleDetector;
    id obj = serializeObject(src, nameTransformer, cycleDetector);
    return obj;
}

+ (id)JSRepresentableValueFromSerializedObject:(id)src {
    return [self JSRepresentableValueFromSerializedObject:src withNameTransformer:nil];
}

+ (id)JSRepresentableValueFromSerializedObject:(id)src withNameTransformer:(JSONNameTransformer)nameTransformer {
    if (!src) return [NSNull null];
    
    ObjSet cycleDetector;
    id js = serializeObject(src, nameTransformer, cycleDetector);
    return js;
}

static id renameFields(id json, JSONNameTransformer transformer) {
    if ([json isKindOfClass:[NSArray class]]) {
        return [json arrayByMappingObjects:^id(id obj) {
            return renameFields(obj, transformer);
        }];
    } else if ([json isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:[json count]];
        for (NSString *key in [json allKeys]) {
            d[transformer(key)] = renameFields(json[key], transformer);
        }
        return d;
    } else {
        return json;
    }
}


+ (id)parseObject:(id)json withNameTransformer:(JSONNameTransformer)nameTransformer
{
    return renameFields(json, nameTransformer);
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

+ (JSONNameTransformer)githubToCocoaNameTransformer {
    return ^(NSString *s) {
        if ([s isEqualToString:@"id"]) {
            return @"identifier";
        }
        if ([s isEqualToString:@"comments"]) {
            return @"commentsCount";
        }
        if ([s isEqualToString:@"events"]) {
            return @"eventsCount";
        }
        if ([s isEqualToString:@"reactions"]) {
            return @"shipReactionSummary";
        }
        if ([s rangeOfString:@"_"].location == NSNotFound) {
            return s;
        }
        NSArray *comps = [s componentsSeparatedByString:@"_"];
        __block NSInteger i = 0;
        comps = [comps arrayByMappingObjects:^id(id obj) {
            i++;
            if (i > 1) {
                return [obj PascalCase];
            } else {
                return obj;
            }
        }];
        return [comps componentsJoinedByString:@""];
    };
}

@end

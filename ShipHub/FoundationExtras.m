//
//  FoundationExtras.m
//  Ship
//
//  Created by James Howard on 9/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "FoundationExtras.h"

#import <AVFoundation/AVFoundation.h>
#import <libkern/OSByteOrder.h>
#import <objc/runtime.h>
#import <zlib.h>
#import <CommonCrypto/CommonCrypto.h>
#import <ImageIO/ImageIO.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>
#else
#import <AppKit/AppKit.h>
#endif

@implementation NSObject (Extras)

- (void)sendAction:(SEL)action toTarget:(id)target {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if (target && action) {
        [target performSelector:action withObject:self];
    }
#pragma clang diagnostic pop
}

- (void)extras_setRepresentedObject:(id)obj {
    objc_setAssociatedObject(self, "extras_representedObject", obj, OBJC_ASSOCIATION_RETAIN);
}

- (id)extras_representedObject {
    return objc_getAssociatedObject(self, "extras_representedObject");
}

+ (BOOL)object:(id)objA isEqual:(id)objB {
    if (objA == nil && objB == nil) return YES;
    if (objA == nil && objB != nil) return NO;
    if (objA != nil && objB == nil) return NO;
    else return [objA isEqual:objB];
}

@end


@implementation NSString (Suffix)

- (NSString *)stringByRemovingSuffix:(NSString *)suffix {
    if ([suffix length] > 0 && [self hasSuffix:suffix]) {
        NSUInteger len = [self length];
        NSUInteger suffixLen = [suffix length];
        return [self substringToIndex:len-suffixLen];
    } else {
        return self;
    }
}

- (NSString *)PascalCase {
    if ([self length] == 0) {
        return self;
    } else {
        NSString *first = [self substringWithRange:NSMakeRange(0, 1)];
        NSString *second = [self substringFromIndex:1];
        return [[first uppercaseString] stringByAppendingString:second];
    }
}

- (NSString *)trim {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)urlencode {
    return [self stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
}

- (NSString *)reverse {
    NSUInteger length = [self length];
    if (length <= 1) return self;
    
    unichar *chars = malloc(sizeof(unichar) * length);
    [self getCharacters:chars range:NSMakeRange(0, length)];
    for (NSUInteger lo = 0, hi = length-1; lo<hi; lo++, hi--) {
        unichar tmp = chars[lo];
        chars[lo] = chars[hi];
        chars[hi] = tmp;
    }
    
    return [[NSString alloc] initWithCharactersNoCopy:chars length:length freeWhenDone:YES];
}

+ (NSString *)stringWithHexBytes:(const uint8_t *)b length:(NSUInteger)bLen {
    NSMutableString *str = [[NSMutableString alloc] initWithCapacity:bLen*2];
    for (NSUInteger i = 0; i < bLen; i++) {
        [str appendFormat:@"%02x", b[i]];
    }
    return str;
}

- (uint64_t)uint64Value {
    NSScanner *scanner = [[NSScanner alloc] initWithString:self];
    uint64_t u64;
    if ([scanner scanUnsignedLongLong:&u64]) {
        return u64;
    } else {
        return 0;
    }
}

static inline uint8_t h2b(uint8_t v) {
    if (v >= 'a' || v <= 'f') {
        return 10 + (v - 'a');
    } else if (v >= 'A' || v <= 'F') {
        return 10 + (v - 'A');
    } else if (v >= '0' || v <= '9') {
        return v - '0';
    } else {
        return 0;
    }
}

- (NSData *)dataFromHexString {
    NSData *asciiData = [self dataUsingEncoding:NSASCIIStringEncoding];
    const uint8_t *ascii = [asciiData bytes];
    NSMutableData *data = [NSMutableData dataWithLength:asciiData.length / 2];
    uint8_t *b = [data mutableBytes];
    NSUInteger l = [data length];
    
    for (NSUInteger i = 0; i < l; i++) {
        uint8_t hi = h2b(ascii[i*2]);
        uint8_t lo = h2b(ascii[(i*2)+1]);
        b[i] = (hi << 4) | lo;
    }
    
    return data;
}

+ (NSComparator)comparatorWithOptions:(NSStringCompareOptions)options {
    return ^(NSString *a, NSString *b) {
        return [a compare:b options:options];
    };
}

- (BOOL)validateEmail {
    NSString *email = [self trim];
    
    if (![email containsString:@"@"]) {
        return NO;
    }
    
    NSArray *split = [email componentsSeparatedByString:@"@"];
    if ([split count] != 2) {
        return NO;
    }
    
    if ([[split[0] trim] length] == 0) {
        return NO;
    }
    
    if (![[split[1] trim] containsString:@"."]) {
        return NO;
    }
    
    return YES;
}

- (BOOL)isDigits {
    static dispatch_once_t onceToken;
    static NSRegularExpression *expr;
    dispatch_once(&onceToken, ^{
        expr = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]+$" options:0 error:NULL];
    });
    return [expr numberOfMatchesInString:self options:0 range:NSMakeRange(0, self.length)] == 1;
}

- (BOOL)isUUID {
    if (!([self length] == 35 || [self length] == 32))
        return NO;
    
    NSString *chars = [self stringByReplacingOccurrencesOfString:@"-" withString:@""];
    if ([chars length] != 32)
        return NO;
    
    static dispatch_once_t onceToken;
    static NSRegularExpression *expr;
    dispatch_once(&onceToken, ^{
        expr = [NSRegularExpression regularExpressionWithPattern:@"^[0-9a-fA-F]+$" options:0 error:NULL];
    });
    
    return [expr numberOfMatchesInString:chars options:0 range:NSMakeRange(0, self.length)] == 1;
}

- (NSString *)stringByCollapsingNewlines {
    static dispatch_once_t onceToken;
    static NSRegularExpression *re;
    dispatch_once(&onceToken, ^{
        re = [NSRegularExpression regularExpressionWithPattern:@"[\n\r]+" options:0 error:NULL];
    });
    
    return [re stringByReplacingMatchesInString:self options:0 range:NSMakeRange(0, self.length) withTemplate:@" "];
}

@end

@implementation NSDateFormatter (Extras)

+ (NSDateFormatter *)ISO8601Formatter {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [formatter setLocale:enUSPOSIXLocale];
        [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSSSSSSZZZZZ"];
    });
    return formatter;
}

+ (NSDateFormatter *)ISO8601FormatterNoFractionalSeconds {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [formatter setLocale:enUSPOSIXLocale];
        [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"UTC"]];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    });
    return formatter;
}

+ (NSDateFormatter *)shortDateFormatter {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterNoStyle];
    });
    return formatter;
}

+ (NSDateFormatter *)shortRelativeDateFormatter {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterNoStyle];
        formatter.doesRelativeDateFormatting = YES;
    });
    return formatter;
}

+ (NSDateFormatter *)shortDateAndTimeFormatter {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterShortStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    });
    return formatter;
}

+ (NSDateFormatter *)longDateAndTimeFormatter {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterLongStyle];
        [formatter setTimeStyle:NSDateFormatterLongStyle];
    });
    return formatter;
}

+ (NSDateFormatter *)shortTimeFormatter {
    static dispatch_once_t onceToken;
    static NSDateFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        [formatter setDateStyle:NSDateFormatterNoStyle];
        [formatter setTimeStyle:NSDateFormatterShortStyle];
    });
    return formatter;
}

@end

@implementation NSDate (Extras)

+ (double)extras_monotonicTime {
    return CACurrentMediaTime();
}

+ (NSDate *)extras_8601Fast:(NSString *)str {
    if (!str) return nil;
    
    // Handles just dates of the form yyyy-MM-dd'T'HH:mm:ss.SSSSSSSZ
    // Or dates of the form yyyy-MM-dd'T'HH:mm:ss.SSSSSSS+00:00
    int y, M, d, H, m, s, S;
    y = M = d = H = m = s = S = 0;
    
    NSScanner *scanner = [[NSScanner alloc] initWithString:str];
    
    if (![scanner scanInt:&y]) return nil;
    if (![scanner scanString:@"-" intoString:NULL]) return nil;
    if (![scanner scanInt:&M]) return nil;
    if (![scanner scanString:@"-" intoString:NULL]) return nil;
    if (![scanner scanInt:&d]) return nil;
    if (![scanner scanString:@"T" intoString:NULL]) return nil;
    if (![scanner scanInt:&H]) return nil;
    if (![scanner scanString:@":" intoString:NULL]) return nil;
    if (![scanner scanInt:&m]) return nil;
    if (![scanner scanString:@":" intoString:NULL]) return nil;
    if (![scanner scanInt:&s]) return nil;
    // Optional . and S
    if ([scanner scanString:@"." intoString:NULL]) {
        NSUInteger pos = scanner.scanLocation;
        if (![scanner scanInt:&S]) return nil;
        NSUInteger SLen = scanner.scanLocation - pos;
        if (SLen > 9) return nil;
        // want S to represent nanoseconds, so it should be 9 digits long
        for (NSUInteger i = SLen; i < 9; i++) {
            S *= 10;
        }
    }
    if (!([scanner scanString:@"Z" intoString:NULL] || [scanner scanString:@"+00:00" intoString:NULL])) return nil;
    if (![scanner isAtEnd]) return nil;
    
    struct tm t;
    memset(&t, 0, sizeof(t));
    t.tm_sec = s;
    t.tm_min = m;
    t.tm_hour = H;
    t.tm_mday = d;
    t.tm_mon = M - 1;
    t.tm_year = y - 1900;
    
    time_t tt = timegm(&t);
    
    NSTimeInterval ti = (double)tt;
    ti += ((double)S / (double)NSEC_PER_SEC);
    
    return [NSDate dateWithTimeIntervalSince1970:ti];
}

+ (NSDate *)dateWithJSONString:(NSString *)str {
    if (!str) return nil;
    
    NSDate *date = nil;
    if ((date = [self extras_8601Fast:str])) {
        return date;
    }
    
    NSDateFormatter *formatter = [NSDateFormatter ISO8601Formatter];
    date = [formatter dateFromString:str];
    if (!date) {
        formatter = [NSDateFormatter ISO8601FormatterNoFractionalSeconds];
        date = [formatter dateFromString:str];
    }
    return date;
}

- (NSString *)JSONString {
    NSDateFormatter *formatter = [NSDateFormatter ISO8601Formatter];
    return [formatter stringFromDate:self];
}

+ (NSDate *)dateWithHTTPHeaderString:(NSString *)str {
    if (!str) return nil;
    
    // http://blog.mro.name/2009/08/nsdateformatter-http-header/
    static dispatch_once_t onceToken;
    static NSDateFormatter *rfc1123;
    static NSDateFormatter *rfc850;
    static NSDateFormatter *asctime;
    dispatch_once(&onceToken, ^{
        NSLocale *locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        NSTimeZone *tz = [[NSTimeZone alloc] initWithName:@"GMT"];
        
        rfc1123 = [NSDateFormatter new];
        rfc1123.locale = locale;
        rfc1123.timeZone = tz;
        rfc1123.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss z";
        
        rfc850 = [NSDateFormatter new];
        rfc850.locale = locale;
        rfc850.timeZone = tz;
        rfc850.dateFormat = @"EEEE',' dd'-'MMM'-'yy HH':'mm':'ss z";
        
        asctime = [NSDateFormatter new];
        asctime.locale = locale;
        asctime.timeZone = tz;
        asctime.dateFormat = @"EEE MMM d HH':'mm':'ss yyyy";
    });
    
    if ([str isDigits]) {
        // it's a time in seconds from now
        return [NSDate dateWithTimeIntervalSinceNow:[str integerValue]];
    } else {
        NSDate *date = nil;
        date = [rfc1123 dateFromString:str];
        if (date) return date;
        date = [rfc850 dateFromString:str];
        if (date) return date;
        date = [asctime dateFromString:str];
        return date;
    }
}

- (NSString *)shortUserInterfaceString {
    NSDateFormatter *formatter = nil;
    if ([self timeIntervalSinceNow] + (12 * 60 * 60) > 0 && [self timeIntervalSinceNow] < (12 * 60 * 60)) {
        formatter = [NSDateFormatter shortTimeFormatter];
    } else {
        formatter = [NSDateFormatter shortDateAndTimeFormatter];
    }
    return [formatter stringFromDate:self];
}

- (NSString *)longUserInterfaceString {
    return [[NSDateFormatter longDateAndTimeFormatter] stringFromDate:self];
}

- (NSDate *)dateByAddingTimeIntervalNumber:(NSNumber *)timeInterval {
    return [self dateByAddingTimeInterval:[timeInterval doubleValue]];
}

- (BOOL)between:(NSDate *)start :(NSDate *)end {
    NSTimeInterval x = self.timeIntervalSinceReferenceDate;
    NSTimeInterval min = start.timeIntervalSinceReferenceDate;
    NSTimeInterval max = end.timeIntervalSinceReferenceDate;
    
    return x >= min && x <= max;
}

- (NSDate *)_ship_addUnit:(NSCalendarUnit)unit value:(NSNumber *)value {
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    return [calendar dateByAddingUnit:unit value:[value integerValue] toDate:self options:0];
}

- (NSDate *)_ship_dateByAddingSeconds:(NSNumber *)seconds {
    return [self _ship_addUnit:NSCalendarUnitSecond value:seconds];
}
- (NSDate *)_ship_dateByAddingMinutes:(NSNumber *)minutes {
    return [self _ship_addUnit:NSCalendarUnitMinute value:minutes];
}
- (NSDate *)_ship_dateByAddingHours:(NSNumber *)hours {
    return [self _ship_addUnit:NSCalendarUnitHour value:hours];
}
- (NSDate *)_ship_dateByAddingDays:(NSNumber *)days {
    return [self _ship_addUnit:NSCalendarUnitDay value:days];
}
- (NSDate *)_ship_dateByAddingMonths:(NSNumber *)months {
    return [self _ship_addUnit:NSCalendarUnitMonth value:months];
}
- (NSDate *)_ship_dateByAddingYears:(NSNumber *)years {
    return [self _ship_addUnit:NSCalendarUnitYear value:years];
}

@end

@implementation NSMutableDictionary (Extras)

- (void)setOptional:(id)optional forKey:(id<NSCopying>)key {
    if (optional) {
        [self setObject:optional forKey:key];
    } else {
        [self removeObjectForKey:key];
    }
}

- (void)filterUsingBlock:(BOOL (^)(id<NSCopying> key, id value))block {
    NSMutableSet *removeTheseKeys = [NSMutableSet set];
    for (id<NSCopying> key in self) {
        id value = self[key];
        if (!block(key, value)) {
            [removeTheseKeys addObject:key];
        }
    }
    [self removeObjectsForKeys:[removeTheseKeys allObjects]];
}

- (void)mapValues:(id (^)(id<NSCopying> key, id value))block {
    NSArray *keys = self.allKeys;
    for (id<NSCopying> key in keys) {
        id value = self[key];
        value = block(key, value);
        self[key] = value;
    }
}

@end

@implementation NSDictionary (Extras)

+ (NSDictionary *)dictionaryWithJSONData:(NSData *)data {
    return [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
}

- (NSData *)JSONRepresentation {
    return [NSJSONSerialization dataWithJSONObject:self options:0 error:NULL];
}

- (NSString *)JSONStringRepresentation {
    return [[NSString alloc] initWithData:[self JSONRepresentation] encoding:NSUTF8StringEncoding];
}

+ (NSDictionary *)lookupWithObjects:(NSArray *)objects keyPath:(NSString *)keyPath {
    NSMutableDictionary *lookup = [NSMutableDictionary dictionaryWithCapacity:[objects count]];
    for (id obj in objects) {
        id key = [obj valueForKeyPath:keyPath];
        if (key) {
            lookup[key] = obj;
        }
    }
    return lookup;
}

- (NSDictionary *)dictionaryByAddingEntriesFromDictionary:(NSDictionary *)newDict {
    NSMutableDictionary *d = [self mutableCopy];
    [d addEntriesFromDictionary:newDict];
    return d;
}

@end

@implementation NSArray (Extras)

- (NSArray *)arrayByMappingObjects:(id (^)(id obj))transformer {
    NSMutableArray *m = [NSMutableArray arrayWithCapacity:self.count];
    for (id obj in self) {
        [m addObject:transformer(obj)];
    }
    return m;
}

- (BOOL)containsObjectMatchingPredicate:(NSPredicate *)predicate {
    for (id obj in self) {
        if ([predicate evaluateWithObject:obj]) {
            return YES;
        }
    }
    return NO;
}

- (id)firstObjectMatchingPredicate:(NSPredicate *)predicate {
    for (id obj in self) {
        if ([predicate evaluateWithObject:obj]) {
            return obj;
        }
    }
    return nil;
}

- (id)lastObjectMatchingPredicate:(NSPredicate *)predicate {
    NSEnumerator *e = self.reverseObjectEnumerator;
    for (id obj in e) {
        if ([predicate evaluateWithObject:obj]) {
            return obj;
        }
    }
    return nil;
}

- (NSArray *)filteredArrayUsingPredicate:(NSPredicate *)predicate limit:(NSUInteger)limit {
    if (limit == 0) return nil;
    
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:limit];
    NSUInteger i = 0;
    for (id obj in self) {
        if ([predicate evaluateWithObject:obj]) {
            [ret addObject:obj];
            i++;
            if (i == limit) {
                break;
            }
        }
    }
    return ret;
}

- (NSArray *)partitionByKeyPath:(NSString *)keyPath {
    NSMutableDictionary *d = [NSMutableDictionary new];
    
    for (id obj in self) {
        id val = [obj valueForKeyPath:keyPath];
        if (!val) val = [NSNull null];
        NSMutableArray *a = d[val];
        if (!a) {
            d[val] = a = [NSMutableArray new];
        }
        [a addObject:obj];
    }
    
    return [d allValues];
}

- (NSComparisonResult)localizedStandardCompareContents:(NSArray *)other {
    NSUInteger c0 = [self count];
    NSUInteger c1 = [other count];
    
    for (NSUInteger i = 0; i < c0 && i < c1; i++) {
        id o0 = self[i];
        id o1 = other[i];
        NSComparisonResult r = [o0 localizedStandardCompare:o1];
        if (r != NSOrderedSame) {
            return r;
        }
    }
    
    if (c0 == c1) {
        return NSOrderedSame;
    } else if (c0 < c1) {
        return NSOrderedAscending;
    } else {
        return NSOrderedDescending;
    }
}

+ (NSArray *)roundRobin:(NSArray<NSArray *> *)arrays {
    NSMutableArray *robin = [NSMutableArray new];
    NSUInteger i = 0;
    while (1) { // loop on i
        NSUInteger s = 0;
        for (NSArray *a in arrays) {
            if (a.count < i) {
                [robin addObject:a[i]];
                s++;
            }
        }
        if (s == 0) break;
        i++;
    }
    return robin;
}

@end

@implementation NSMutableArray (Extras)

- (void)moveItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSInteger)idx {
    if ([indexes count] == 0) return;
    
    __block NSInteger dstIdx = idx;
    [indexes enumerateIndexesUsingBlock:^(NSUInteger j, BOOL * _Nonnull stop) {
        if (j < idx) dstIdx--;
    }];
    
    if (dstIdx < 0) dstIdx = 0;
    
    NSArray *items = [self objectsAtIndexes:indexes];
    
    [self removeObjectsAtIndexes:indexes];
    
    NSIndexSet *insertionPoints = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(dstIdx, [indexes count])];
    
    [self insertObjects:items atIndexes:insertionPoints];
}

@end

@implementation NSSet (Extras)

- (NSSet *)setByMappingObjects:(id (^)(id obj))transformer {
    return [NSSet setWithArray:[[self allObjects] arrayByMappingObjects:transformer]];
}

@end

@implementation NSOrderedSet (Extras)

- (NSOrderedSet *)orderedSetByMappingObjects:(id (^)(id obj))transformer {
    return [NSOrderedSet orderedSetWithArray:[[self array] arrayByMappingObjects:transformer]];
}

@end

@implementation NSPredicate (Extras)

- (NSPredicate *)and:(NSPredicate *)predicate {
    return [NSCompoundPredicate andPredicateWithSubpredicates:@[self, predicate]];
}

- (NSPredicate *)or:(NSPredicate *)predicate {
    return [NSCompoundPredicate orPredicateWithSubpredicates:@[self, predicate]];
}

@end

@implementation NSManagedObjectContext (Extras)

- (void)performBlock:(dispatch_block_t)block completion:(dispatch_block_t)completion {
    [self performBlock:^{
        block();
        if (completion) completion();
    }];
}

- (void)purge {
    // In 10.11 there will be a more efficient way to do this.
    NSUInteger purged = 0;
    NSManagedObjectModel *mom = self.persistentStoreCoordinator.managedObjectModel;
    for (NSEntityDescription *entity in mom.entities) {
        if (!entity.abstract) {
            NSFetchRequest *fetch = [NSFetchRequest fetchRequestWithEntityName:entity.name];
            for (NSManagedObject *obj in [self executeFetchRequest:fetch error:NULL]) {
                [self deleteObject:obj];
                purged++;
            }
        }
    }
    NSError *err = nil;
    [self save:&err];
    if (err) {
        ErrLog(@"%@", err);
    } else {
        DebugLog(@"Purged %tu entities", purged);
    }
}

- (BOOL)batchDeleteEntitiesWithRequest:(NSFetchRequest *)request error:(NSError * __autoreleasing *)error
{
    NSError *err = nil;
    if ([NSBatchDeleteRequest class]) {
        // 10.11/iOS 9 path
        NSBatchDeleteRequest *batch = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [self executeRequest:batch error:&err];
    } else {
        // 10.10 path
        for (NSManagedObject *obj in [self executeFetchRequest:request error:&err]) {
            [self deleteObject:obj];
        }
    }
    if (error) {
        *error = err;
        return NO;
    } else {
        return YES;
    }
}

@end

@implementation NSManagedObject (Extras)

- (NSDictionary *)allAttributeValues {
    NSDictionary *attributes = self.entity.attributesByName;
    NSMutableDictionary *all = [NSMutableDictionary dictionaryWithCapacity:attributes.count];
    for (NSString *key in attributes) {
        id val = [self valueForKey:key];
        if (val) {
            all[key] = val;
        }
    }
    return all;
}

- (id)_ship_handleComputedJSON:(NSString *)computeSelector key:(NSString *)key dict:(NSDictionary *)d {
    SEL sel = NSSelectorFromString(computeSelector);
    NSMethodSignature *sig = [self methodSignatureForSelector:sel];
    
    NSAssert(sig != nil, @"%@ must implement %@ as defined for computeJSON userInfo key for Core Data attribute %@",
             self, computeSelector, key);
    
    NSAssert(sig.numberOfArguments == 4, @"-[%@ %@] must take exactly 2 arguments: propertyKey: and dictionary:", NSStringFromClass([self class]), computeSelector);
    
    NSInvocation *ivk = [NSInvocation invocationWithMethodSignature:sig];
    ivk.target = self;
    ivk.selector = sel;
    [ivk setArgument:&key atIndex:2];
    [ivk setArgument:&d atIndex:3];
    
    [ivk invoke];
    
    void *ret = NULL;
    [ivk getReturnValue:&ret];
    
    id val = (__bridge id)ret;
    
    return val;
}

- (void)mergeAttributesFromDictionary:(NSDictionary *)d onlyIfChanged:(BOOL)onlyIfChanged {
    NSDictionary *attributes = self.entity.attributesByName;
    for (NSString *key in [attributes allKeys]) {
        NSAttributeDescription *desc = attributes[key];
        NSString *dictKey = desc.userInfo[@"jsonKey"];
        NSString *computeSelector = nil;
        if (!dictKey) dictKey = key;
        id val = nil;
        if ([key isEqualToString:@"rawJSON"]) {
            val = [NSJSONSerialization dataWithJSONObject:d options:0 error:NULL];
        } else if ((computeSelector = desc.userInfo[@"computeJSON"]) != nil) {
            val = [self _ship_handleComputedJSON:computeSelector key:key dict:d];
        } else {
            val = d[dictKey];
        }
        if ([val isKindOfClass:[NSString class]] && [desc attributeType] == NSDateAttributeType) {
            val = [NSDate dateWithJSONString:val];
        }
        if (val == nil) val = desc.defaultValue;
        if (val == [NSNull null]) val = nil;
        if (onlyIfChanged) {
            id oldVal = [self valueForKey:key];
            if (oldVal == val || [oldVal isEqual:val]) {
                continue;
            }
        }
        [self setValue:val forKey:key];
    }
}

- (void)mergeAttributesFromDictionary:(NSDictionary *)d {
    [self mergeAttributesFromDictionary:d onlyIfChanged:YES];
}

static BOOL equal(id a, id b) {
    if (!a && !b) return YES;
    if (a && !b) return NO;
    if (!a && b) return NO;
    if (a == b) return YES;
    
    if ([a isKindOfClass:[NSOrderedSet class]]) {
        if ([a count] == 0 && [b count] == 0) {
            return YES;
        } else if ([a count] != [b count]) {
            return NO;
        } else if ([[a firstObject] isKindOfClass:[NSManagedObject class]]) {
            NSOrderedSet *aID = [a orderedSetByMappingObjects:^id(id obj) { return [obj objectID]; }];
            NSOrderedSet *bID = [b orderedSetByMappingObjects:^id(id obj) { return [obj objectID]; }];
            return [aID isEqual:bID];
        } else {
            return [a isEqual:b];
        }
    } else if ([a isKindOfClass:[NSSet class]]) {
        if ([a count] == 0 && [b count] == 0) {
            return YES;
        } else if ([a count] != [b count]) {
            return NO;
        } else if ([[a anyObject] isKindOfClass:[NSManagedObject class]]) {
            NSSet *aID = [a setByMappingObjects:^id(id obj) { return [obj objectID]; }];
            NSSet *bID = [b setByMappingObjects:^id(id obj) { return [obj objectID]; }];
            return [aID isEqual:bID];
        } else {
            return [a isEqual:b];
        }
    } else if ([a isKindOfClass:[NSManagedObject class]]) {
        return [[a objectID] isEqual:[b objectID]];
    } else {
        return [a isEqual:b];
    }
}

- (void)setValue:(id)value forKey:(NSString *)key onlyIfChanged:(BOOL)onlyIfChanged {
    if (!onlyIfChanged) {
        [self setValue:value forKey:key];
        return;
    }
    
    id existing = [self valueForKey:key];
    if (!equal(value, existing)) {
        [self setValue:value forKey:key];
    }
}

@end

@implementation NSNotification (CoreDataExtras)

- (void)enumerateModifiedObjects:(void (^)(id obj, CoreDataModificationType modType, BOOL *stop))block
{
    NSParameterAssert(block);
    
    NSDictionary *info = [self userInfo];
    BOOL stop = NO;
    
    for (id obj in info[NSInsertedObjectsKey]) {
        block(obj, CoreDataModificationTypeInserted, &stop);
        if (stop) return;
    }
    
    for (id obj in info[NSUpdatedObjectsKey]) {
        block(obj, CoreDataModificationTypeUpdated, &stop);
        if (stop) return;
    }
    
    for (id obj in info[NSDeletedObjectsKey]) {
        block(obj, CoreDataModificationTypeDeleted, &stop);
        if (stop) return;
    }
}

@end

void Extras_dispatch_assert_current_queue(dispatch_queue_t q) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSCAssert(q == dispatch_get_current_queue(), @"Current dispatch_queue must be %@", q);
#pragma diagnostic pop
}

void RunOnMain(dispatch_block_t work) {
    if ([NSThread isMainThread]) {
        work();
    } else {
        dispatch_async(dispatch_get_main_queue(), work);
    }
}

BOOL NSRangeContainsRange(NSRange outer, NSRange inner) {
    NSInteger outerMin = outer.location;
    NSInteger outerMax = outer.location + outer.length;
    NSInteger innerMin = inner.location;
    NSInteger innerMax = inner.location + inner.length;
    
    return outerMin <= innerMin && outerMax >= innerMax;
}

BOOL NSRangeIntersectsRange(NSRange a, NSRange b) {
    NSRange intersection = NSIntersectionRange(a, b);
    return intersection.length > 0;
}

CGRect CenteredRectInRect(CGRect outer, CGRect inner) {
    return CGRectMake(round(CGRectGetMinX(outer) + (CGRectGetWidth(outer) - CGRectGetWidth(inner)) / 2.0),
                      round(CGRectGetMinY(outer) + (CGRectGetHeight(outer) - CGRectGetHeight(inner)) / 2.0),
                      CGRectGetWidth(inner), CGRectGetHeight(inner));
    
}

CGRect CenteredRectInRectWithoutRounding(CGRect outer, CGRect inner) {
    return CGRectMake((CGRectGetMinX(outer) + (CGRectGetWidth(outer) - CGRectGetWidth(inner)) / 2.0),
                      (CGRectGetMinY(outer) + (CGRectGetHeight(outer) - CGRectGetHeight(inner)) / 2.0),
                      CGRectGetWidth(inner), CGRectGetHeight(inner));
    
}


CGRect IntegralRect(CGRect r) {
    r.origin.x = round(r.origin.x);
    r.origin.y = round(r.origin.y);
    r.size.width = round(r.size.width);
    r.size.height = round(r.size.height);
    return r;
}

@implementation NSData (Extras)

// Code adapted from http://www.zlib.net/zlib_how.html
#define CHUNK 4096

- (NSData *)inflate {
    NSInputStream *input = [NSInputStream inputStreamWithData:self];
    NSOutputStream *output = [NSOutputStream outputStreamToMemory];
    
    [input open];
    [output open];
    
    int ret;
    unsigned have;
    z_stream strm;
    unsigned char inb[CHUNK];
    unsigned char outb[CHUNK];
    
    /* allocate inflate state */
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.avail_in = 0;
    strm.next_in = Z_NULL;
    ret = inflateInit2(&strm, MAX_WBITS|32);
    if (ret != Z_OK)
        return nil;
    
    /* decompress until deflate stream ends or end of file */
    do {
        NSInteger read = (uInt)[input read:inb maxLength:CHUNK];
        if (read < 0) {
            (void)inflateEnd(&strm);
            return nil;
        }
        strm.avail_in = (uInt)read;
        if (strm.avail_in == 0)
            break;
        strm.next_in = inb;
        
        /* run inflate() on input until output buffer not full */
        do {
            strm.avail_out = CHUNK;
            strm.next_out = outb;
            
            ret = inflate(&strm, Z_NO_FLUSH);
            assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
            switch (ret) {
                case Z_NEED_DICT:
                    /* ret = Z_DATA_ERROR; */     /* and fall through */
                case Z_DATA_ERROR:
                case Z_MEM_ERROR:
                    (void)inflateEnd(&strm);
                    return nil;
            }
            
            have = CHUNK - strm.avail_out;
            if (![output write:outb length:have]) {
                (void)inflateEnd(&strm);
                return nil;
            }
        } while (strm.avail_out == 0);
        /* done when inflate() says it's done */
    } while (ret != Z_STREAM_END);
    
    /* clean up and return */
    (void)inflateEnd(&strm);
    
    if (ret == Z_STREAM_END) {
        NSData *data = [output propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        return data;
    } else {
        return nil;
    }
}

- (NSData *)deflate {
    NSInputStream *input = [NSInputStream inputStreamWithData:self];
    NSOutputStream *output = [NSOutputStream outputStreamToMemory];
    
    [input open];
    [output open];
    
    int ret, flush;
    unsigned have;
    z_stream strm;
    unsigned char inb[CHUNK];
    unsigned char outb[CHUNK];
    
    /* allocate deflate state */
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    ret = deflateInit2(&strm, Z_DEFAULT_COMPRESSION, Z_DEFLATED, MAX_WBITS | 16, 8, Z_DEFAULT_STRATEGY);
    if (ret != Z_OK)
        return nil;
    
    /* compress until end of file */
    do {
        NSInteger read = [input read:inb maxLength:CHUNK];
        if (read < 0) {
            (void)deflateEnd(&strm);
            return nil;
        }
        strm.avail_in = (uInt)read;
        flush = ![input hasBytesAvailable] ? Z_FINISH : Z_NO_FLUSH;
        strm.next_in = inb;
        
        /* run deflate() on input until output buffer not full, finish
         compression if all of source has been read in */
        do {
            strm.avail_out = CHUNK;
            strm.next_out = outb;
            ret = deflate(&strm, flush);    /* no bad return value */
            assert(ret != Z_STREAM_ERROR);  /* state not clobbered */
            have = CHUNK - strm.avail_out;
            NSUInteger written = 0;
            while (written < have) {
                written += [output write:outb+written maxLength:have-written];
            }
        } while (strm.avail_out == 0);
        assert(strm.avail_in == 0);     /* all input will be used */
        /* done when last data in file processed */
    } while (flush != Z_FINISH);
    assert(ret == Z_STREAM_END);        /* stream will be complete */
    
    /* clean up and return */
    (void)deflateEnd(&strm);
    
    NSData *data = [output propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    return data;
}

- (NSString *)MD5String {
    NSAssert([self length] < UINT32_MAX, @"CC_MD5 only works on items < 4GB");
    unsigned char md5[CC_MD5_DIGEST_LENGTH];
    CC_MD5([self bytes], (CC_LONG)[self length], md5);
    return [NSString stringWithHexBytes:md5 length:CC_MD5_DIGEST_LENGTH];
}

- (NSString *)SHA1String {
    NSAssert([self length] < UINT32_MAX, @"CC_SHA1 only works on items < 4GB");
    unsigned char sha1[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([self bytes], (CC_LONG)[self length], sha1);
    return [NSString stringWithHexBytes:sha1 length:CC_SHA1_DIGEST_LENGTH];
}


@end

@implementation NSString (Extras_FileTypes)

- (NSString *)mimeTypeFromUTI {
    NSString *mime = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)self, kUTTagClassMIMEType);
    if (!mime) {
        if ([self isEqualToString:(__bridge NSString *)kUTTypeLog] || [self isEqualToString:@"com.apple.log"]) {
            mime = @"text/plain";
        }
    }
    return mime;
}

- (NSString *)UTIFromMimeType {
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(self), NULL);
    return UTI;
}

- (NSString *)UTIFromExtension {
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)(self), NULL);
    return UTI;
}

- (NSString *)UTIFromFilename {
    return [[self pathExtension] UTIFromExtension];
}

- (NSString *)extensionFromUTI {
    NSString *ext = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)self, kUTTagClassFilenameExtension);
    return ext;
}

- (BOOL)isImageMimeType {
    return [[self UTIFromMimeType] isImageUTI];
}

- (BOOL)isAVMimeType {
    return [[self UTIFromMimeType] isAVUTI];
}

- (BOOL)isImageUTI {
    static NSArray *knownImageTypes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        knownImageTypes = (__bridge_transfer NSArray *)CGImageSourceCopyTypeIdentifiers();
    });
    return [knownImageTypes containsObject:self];
    
}

- (BOOL)isAVUTI {
    NSArray *knownTypes = [AVURLAsset audiovisualTypes];
    return [knownTypes containsObject:self];
}

@end


@implementation NSFileWrapper (Extras)

- (NSString *)uniformTypeIdentifier {
    return [self.preferredFilename.pathExtension UTIFromExtension];
}

- (NSString *)mimeType {
    return [[self uniformTypeIdentifier] mimeTypeFromUTI] ?: @"application/octet-stream";
}

- (BOOL)isImageType {
    return [[self uniformTypeIdentifier] isImageUTI];
}

- (BOOL)isAVType {
    return [[self uniformTypeIdentifier] isAVUTI];
}

@end

@implementation NSOutputStream (Extras)

- (BOOL)writeData:(NSData *)data {
    const uint8_t *bytes = [data bytes];
    NSUInteger length = [data length];
    return [self write:bytes length:length];
}

- (BOOL)write:(const uint8_t *)bytes length:(NSInteger)length {
    NSUInteger written = 0;
    
    while (written < length) {
        NSInteger didWrite = [self write:bytes+written maxLength:length-written];
        if (didWrite < 0) {
            return NO;
        }
        written += didWrite;
    }
    
    return YES;
}

@end

@implementation NSFileManager (Extras)

- (NSString *)sha1:(NSString *)filePath error:(NSError **)error {
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:filePath];
    [stream open];
    
    uint8_t buf[32768];
    CC_SHA1_CTX sha1Ctx;
    CC_SHA1_Init(&sha1Ctx);
    
    NSInteger read;
    while ((read = [stream read:buf maxLength:sizeof(buf)]) > 0) {
        CC_SHA1_Update(&sha1Ctx, buf, (CC_LONG)read);
    }
    uint8_t sha1Bytes[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_Final(sha1Bytes, &sha1Ctx);
    
    if (error && stream.streamStatus == NSStreamStatusError) {
        *error = stream.streamError;
        return nil;
    }
    
    return [NSString stringWithHexBytes:sha1Bytes length:sizeof(sha1Bytes)];
}

- (NSString *)md5:(NSString *)filePath error:(NSError **)error {
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:filePath];
    [stream open];
    
    uint8_t buf[32768];
    CC_MD5_CTX md5Ctx;
    CC_MD5_Init(&md5Ctx);
    
    NSInteger read;
    while ((read = [stream read:buf maxLength:sizeof(buf)]) > 0) {
        CC_MD5_Update(&md5Ctx, buf, (CC_LONG)read);
    }
    uint8_t md5Bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(md5Bytes, &md5Ctx);
    
    if (error && stream.streamStatus == NSStreamStatusError) {
        *error = stream.streamError;
        return nil;
    }
    
    return [NSString stringWithHexBytes:md5Bytes length:sizeof(md5Bytes)];
}

@end

@implementation NSProgress (Extras)

+ (NSProgress *)indeterminateProgress {
    return [NSProgress progressWithTotalUnitCount:-1];
}

@end

@implementation NSUUID (Extras)

- (NSString *)shortString {
    uuid_t uuid;
    [self getUUIDBytes:uuid];
    NSData *d = [[NSData alloc] initWithBytesNoCopy:uuid length:sizeof(uuid) freeWhenDone:NO];
    NSString *b64 = [d base64EncodedStringWithOptions:0];
    // strip trailing == since we know the length
    b64 = [b64 substringWithRange:NSMakeRange(0, b64.length-2)];
    return b64;
}

- (id)initWithShortString:(NSString *)str {
    str = [str stringByAppendingString:@"=="];
    NSData *d = [[NSData alloc] initWithBase64EncodedString:str options:0];
    if ([d length] != 16) return nil;
    
    uuid_t uuid;
    [d getBytes:uuid length:sizeof(uuid)];
    
    return [self initWithUUIDBytes:uuid];
}

@end

@interface PositiveOnlyIntegerFormatter : NSNumberFormatter

@end

@implementation PositiveOnlyIntegerFormatter

- (NSString *)stringForObjectValue:(id)obj {
    if ([obj isKindOfClass:[NSNumber class]]) {
        return [self stringFromNumber:obj];
    } else {
        return @"";
    }
}

- (NSString *)stringFromNumber:(NSNumber *)number {
    if (number.integerValue < 1) {
        return @"";
    } else {
        return [NSString localizedStringWithFormat:@"%td", number.integerValue];
    }
}

@end

@implementation NSNumberFormatter (Extras)

+ (NSNumberFormatter *)positiveOnlyIntegerFormatter {
    static dispatch_once_t onceToken;
    static PositiveOnlyIntegerFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [PositiveOnlyIntegerFormatter new];
    });
    return formatter;
}

+ (NSNumberFormatter *)positiveAndNegativeIntegerFormatter {
    static dispatch_once_t onceToken;
    static NSNumberFormatter *formatter;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.positiveFormat = @"0";
        formatter.negativeFormat = @"(0)";
#if TARGET_OS_IPHONE
        formatter.textAttributesForNegativeValues = @{ NSForegroundColorAttributeName : [UIColor redColor] };
#else
        formatter.textAttributesForNegativeValues = @{ NSForegroundColorAttributeName : [NSColor redColor] };
#endif
    });
    return formatter;
}

@end

@implementation BooleanFormatter : NSFormatter

- (NSString *)stringForObjectValue:(id)obj {
    if (!obj) {
        return NSLocalizedString(@"No", nil);
    }
    
    if ([obj isKindOfClass:[NSNumber class]]) {
        if ([obj boolValue]) {
            return NSLocalizedString(@"Yes", nil);
        } else {
            return NSLocalizedString(@"No", nil);
        }
    }
    
    return @"";
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error {
    BOOL val = [string boolValue];
    *obj = [NSNumber numberWithBool:val];
    return YES;
}

@end

#if TARGET_OS_IOS
@interface UIColor (LayeringViolation)
+ (UIColor *)extras_controlBlue;
@end
#else
@interface NSColor (LayeringViolation)
+ (NSColor *)extras_controlBlue;
@end
#endif

@implementation BooleanDotFormatter

#if TARGET_OS_IOS
+ (BooleanDotFormatter *)formatterWithColor:(UIColor *)color;
#else
+ (BooleanDotFormatter *)formatterWithColor:(NSColor *)color;
#endif
{
    BooleanDotFormatter *f = [BooleanDotFormatter new];
    f.color = color;
    return f;
}

- (NSAttributedString *)attributedStringForObjectValue:(id)obj withDefaultAttributes:(NSDictionary<NSString *,id> *)attrs
{
    NSString *base = [self stringForObjectValue:obj];
    NSMutableDictionary *myAttrs = [attrs mutableCopy];
    
    static NSParagraphStyle *centered = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
        para.alignment = NSTextAlignmentCenter;
        centered = para;
    });
    
    myAttrs[NSParagraphStyleAttributeName] = centered;

    id font = myAttrs[NSFontAttributeName];
#if TARGET_OS_IPHONE
    font = [font fontWithSize:20.0];
#else
    font = [NSFont fontWithName:[font fontName] size:20.0];
#endif
    myAttrs[NSFontAttributeName] = font;
    
#if TARGET_OS_IOS
    myAttrs[NSForegroundColorAttributeName] = _color ?: [UIColor extras_controlBlue];
#else
    myAttrs[NSForegroundColorAttributeName] = _color ?: [NSColor extras_controlBlue];
#endif
    
    return [[NSAttributedString alloc] initWithString:base attributes:myAttrs];
}

- (NSString *)stringForObjectValue:(id)obj {
    if (!obj) {
        return @"";
    }
    
    if ([obj isKindOfClass:[NSNumber class]]) {
        if ([obj boolValue]) {
            return @"•";
        } else {
            return @"";
        }
    }
    
    return @"";
}

- (BOOL)getObjectValue:(out id *)obj forString:(NSString *)string errorDescription:(out NSString **)error {
    BOOL val = [string boolValue];
    *obj = [NSNumber numberWithBool:val];
    return YES;
}


@end

@implementation NSMutableAttributedString (Extras)

- (void)appendAttributes:(NSDictionary *)attributes format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *str = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    [self appendAttributedString:[[NSAttributedString alloc] initWithString:str attributes:attributes]];
}

@end

@implementation NSIndexSet (Extras)

- (NSUInteger)anyIndex {
    if (self.count == 0) return NSNotFound;
    NSUInteger ret = 0;
    NSUInteger gotten = [self getIndexes:&ret maxCount:1 inIndexRange:NULL];
#ifndef DEBUG
    (void)gotten;
#endif
    NSAssert(1 == gotten, @"Must read 1 index");
    return ret;
}

@end

@implementation NSAttributedString (Extras)

- (NSString *)_stringWithDocumentType:(NSString *)docType {
    NSRange range = NSMakeRange(0, [self length]);
    NSError *err = nil;
    NSData *data = [self dataFromRange:range documentAttributes:@{NSDocumentTypeDocumentAttribute:docType, NSCharacterEncodingDocumentAttribute: @(NSUTF8StringEncoding)} error:&err];
    if (err) {
        ErrLog(@"%@ export failed: %@", docType, err);
    }
    
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSString *)html {
    return [self _stringWithDocumentType:NSHTMLTextDocumentType];
}

- (NSString *)rtf {
    return [self _stringWithDocumentType:NSRTFTextDocumentType];
}

- (NSString *)plainText {
    return [self _stringWithDocumentType:NSPlainTextDocumentType];
}

#if TARGET_OS_IPHONE
- (BOOL)containsAttachments {
    NSString *str = [self string];
    for (NSUInteger i = 0; i < [str length]; i++) {
        unichar c = [str characterAtIndex:i];
        if (c == NSAttachmentCharacter) {
            return YES;
        }
    }
    return NO;
}
#endif

- (BOOL)hasContents {
    if ([self containsAttachments]) return YES;
    NSString *plainText = [self plainText];
    if ([[plainText trim] length] > 0) return YES;
    return NO;
}

#if TARGET_OS_IPHONE
+ (NSAttributedString *)attributedStringWithRTFString:(NSString *)rtf {
    NSData *data = [rtf dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *opts = @{ NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType, NSCharacterEncodingDocumentAttribute : @(NSUTF8StringEncoding) };
    return [[NSAttributedString alloc] initWithData:data options:opts documentAttributes:NULL error:NULL];
}

+ (NSAttributedString *)attributedStringWithHTMLString:(NSString *)html {
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *opts = @{ NSDocumentTypeDocumentAttribute : NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute : @(NSUTF8StringEncoding) };
    return [[NSAttributedString alloc] initWithData:data options:opts documentAttributes:NULL error:NULL];
}
#else
+ (NSAttributedString *)attributedStringWithRTFString:(NSString *)rtf {
    NSData *data = [rtf dataUsingEncoding:NSUTF8StringEncoding];
    return [[NSAttributedString alloc] initWithRTF:data documentAttributes:nil];
}

+ (NSAttributedString *)attributedStringWithHTMLString:(NSString *)html {
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    return [[NSAttributedString alloc] initWithHTML:data baseURL:[NSURL URLWithString:@"about:blank"] documentAttributes:nil];
}
#endif

+ (NSAttributedString *)attributedStringWithPlainText:(NSString *)plainText {
    return [[NSAttributedString alloc] initWithString:plainText];
}

+ (NSDictionary *)defaultAttributes {
    NSParagraphStyle *defaultPara = [NSParagraphStyle defaultParagraphStyle];
    return @{ NSParagraphStyleAttributeName : defaultPara,
#if TARGET_OS_IPHONE
              NSFontAttributeName : [UIFont fontWithName:@"Helvetica" size:12.0],
              NSForegroundColorAttributeName : [UIColor blackColor],
#else
              NSFontAttributeName : [NSFont fontWithName:@"Helvetica" size:12.0],
              NSForegroundColorAttributeName : [NSColor blackColor],
              NSSuperscriptAttributeName : @0,
#endif
              NSBaselineOffsetAttributeName : @0.0,
              NSKernAttributeName : @0.0,
              NSLigatureAttributeName : @1,
              NSUnderlineStyleAttributeName : @(NSUnderlineStyleNone) };
}

- (NSRange)rangeOfTextAttachment:(NSTextAttachment *)attachment {
    __block NSRange ret = NSMakeRange(NSNotFound, 0);
    [self enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, [self length]) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
        if (value == attachment) {
            ret = range;
            *stop = YES;
        }
    }];
    return ret;
}

- (NSAttributedString *)scaleFontSizesBy:(CGFloat)scale {
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithAttributedString:self];
    [self enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, self.length) options:0 usingBlock:^(id  _Nullable font, NSRange range, BOOL * _Nonnull stop) {
        if (font) {
#if TARGET_OS_IPHONE
            font = [font fontWithSize:[font pointSize] * scale];
#else
            font = [NSFont fontWithName:[font fontName] size:[font pointSize] * scale];
#endif
            [str addAttribute:NSFontAttributeName value:font range:range];
        }
    }];
    return str;
}

- (NSAttributedString *)trimTrailingWhitespace {
    NSMutableAttributedString *trimmed = [self mutableCopy];
    NSMutableString *ms = [trimmed mutableString];
    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    
    NSInteger t = (NSInteger)([ms length]) - 1;
    for (; t >= 0; t--) {
        unichar c = [ms characterAtIndex:t];
        if (![ws characterIsMember:c]) {
            break;
        }
    }
    t++;
    
    if (t < [ms length]) {
        [ms deleteCharactersInRange:NSMakeRange(t, [ms length]-t)];
    }

    return trimmed;
}

+ (NSString *)attachmentPlaceholderCharacterAsString {
    static NSString *str;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        str = [NSString stringWithFormat:@"%C", (unichar)(0x001A)];
    });
    return str;
}

@end

@interface WeakTimerTarget : NSObject

@property (weak) id target;
@property SEL selector;

@end

@implementation WeakTimerTarget

- (void)timerFired:(NSTimer *)timer {
    id target = self.target;
    SEL selector = self.selector;
    if (target) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        if (target && selector) {
            [target performSelector:selector withObject:timer];
        }
#pragma clang diagnostic pop
    }
}

@end

@implementation NSTimer (WeakTimer)

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti weakTarget:(id)aTarget selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)yesOrNo
{
    WeakTimerTarget *weakTarget = [WeakTimerTarget new];
    weakTarget.target = aTarget;
    weakTarget.selector = aSelector;
    return [NSTimer scheduledTimerWithTimeInterval:ti target:weakTarget selector:@selector(timerFired:) userInfo:userInfo repeats:yesOrNo];
}

@end

@interface URLSessionResult () {
    id _json;
}

@end

@implementation URLSessionResult

- (id)json {
    if (_json) {
        return _json;
    }
    
    if (_data && !_error) {
        NSError *parseError = nil;
        _json = [NSJSONSerialization JSONObjectWithData:_data options:0 error:&parseError];
        if (parseError) {
            self.error = parseError;
        }
    }
    
    return _json;
}

+ (NSError *)anyErrorInResults:(NSArray<URLSessionResult *> *)results {
    for (URLSessionResult *result in results) {
        if (result.error) {
            return result.error;
        }
    }
    return nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> { %@ }", NSStringFromClass([self class]), self, self.response];
}

@end

@implementation NSURLSession (ParallelExtras)

- (NSArray *)dataTasksWithRequests:(NSArray<NSURLRequest *> *)requests completion:(void (^)(NSArray<URLSessionResult *> *))completion;
{
    NSMutableArray *tasks = [NSMutableArray arrayWithCapacity:requests.count];
    NSMutableArray *responses = [NSMutableArray arrayWithCapacity:requests.count];
    
    // Used to wait on the group of requests
    dispatch_group_t group = dispatch_group_create();
    
    for (NSURLRequest *request in requests) {
        URLSessionResult *result = [URLSessionResult new];
        [responses addObject:result];
        
        dispatch_group_enter(group);
        NSURLSessionDataTask *task = [self dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            result.data = data;
            result.response = response;
            result.error = error;
            
            dispatch_group_leave(group);
        }];
        [tasks addObject:task];
    }
    
    for (NSURLSessionDataTask *task in tasks) {
        [task resume];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(responses);
    });
    
    return tasks;
}

@end

@interface URLSessionDownloadTaskProgress : NSProgress

- (id)initWithTask:(NSURLSessionTask *)task;

@end

@implementation URLSessionDownloadTaskProgress {
    NSURLSessionTask *_task;
}

- (id)initWithTask:(NSURLSessionTask *)task {
    if (self = [super init]) {
        _task = task;
        [task addObserver:self forKeyPath:@"countOfBytesReceived" options:0 context:NULL];
        [task addObserver:self forKeyPath:@"countOfBytesExpectedToReceive" options:0 context:NULL];
        [task addObserver:self forKeyPath:@"taskDescription" options:0 context:NULL];
        [self updateFromTask];
    }
    return self;
}

- (void)dealloc {
    [_task removeObserver:self forKeyPath:@"countOfBytesReceived" context:NULL];
    [_task removeObserver:self forKeyPath:@"countOfBytesExpectedToReceive" context:NULL];
    [_task removeObserver:self forKeyPath:@"taskDescription" context:NULL];
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    [super addObserver:observer forKeyPath:keyPath options:options context:context];
}

- (void)updateFromTask {
    self.totalUnitCount = _task.countOfBytesExpectedToReceive;
    self.completedUnitCount = _task.countOfBytesReceived;
    self.localizedDescription = _task.taskDescription;
}

- (void)cancel {
    [_task cancel];
    [super cancel];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    [self updateFromTask];
}

@end

@implementation NSURLSessionTask (ProgressExtras)

- (NSProgress *)downloadProgress {
    return [[URLSessionDownloadTaskProgress alloc] initWithTask:self];
}

@end

@implementation NSMutableURLRequest (BasicAuthExtras)

- (void)addBasicAuthorizationHeaderForUsername:(NSString *)username password:(NSString *)password {
    NSString *alpha = [NSString stringWithFormat:@"%@:%@", username, password];
    NSString *b64 = [[alpha dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0];
    
    [self setValue:[NSString stringWithFormat:@"Basic %@", b64] forHTTPHeaderField:@"Authorization"];
}

@end


@implementation NSError (Extras)

- (BOOL)isCancelError {
    return [self code] == NSURLErrorCancelled && [[self domain] isEqualToString:NSURLErrorDomain];
}

+ (NSError *)cancelError {
    return [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil];
}

@end

@implementation NSHTTPURLResponse (Extras)

- (BOOL)isSuccessStatusCode {
    NSInteger status = self.statusCode;
    return status >= 200 && status < 400;
}

@end

@implementation NSURLComponents (Extras)

- (void)setQueryItemsDictionary:(NSDictionary *)params {
    NSMutableArray *qps = [NSMutableArray new];
    for (NSString *k in [params allKeys]) {
        id v = params[k];
        [qps addObject:[NSURLQueryItem queryItemWithName:k value:[v description]]];
    }
    self.queryItems = qps;
}

- (NSDictionary *)queryItemsDictionary {
    NSMutableDictionary *d = [NSMutableDictionary new];
    for (NSURLQueryItem *qp in self.queryItems) {
        d[qp.name] = qp.value;
    }
    return d;
}

@end

#if !TARGET_OS_IOS
@implementation NSTask (Extras)

- (int)launchAndWaitForTermination {
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    self.terminationHandler = ^(NSTask *t) {
        dispatch_semaphore_signal(sema);
    };
    [self launch];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return [self terminationStatus];
}

@end
#endif

@implementation NSBundle (Extras)

- (NSString *)extras_userAgentString {
    static dispatch_once_t onceToken;
    static NSString *ua;
    dispatch_once(&onceToken, ^{
        NSDictionary *userInfo = [[NSBundle mainBundle] infoDictionary];
        ua = [NSString stringWithFormat:@"%@/%@ (%@)", userInfo[@"CFBundleName"], userInfo[@"CFBundleShortVersionString"], userInfo[@"CFBundleVersion"]];
    });
    return ua;
}

@end

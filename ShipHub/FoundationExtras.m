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

+ (NSDate *)extras_8601Fast:(NSString *)str {
    if (!str) return nil;
    
    // Handles just dates of the form yyyy-MM-dd'T'HH:mm:ss.SSSSSSSZ
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
    if (![scanner scanString:@"Z" intoString:NULL]) return nil;
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

- (NSDate *)_addUnit:(NSCalendarUnit)unit value:(NSNumber *)value {
    NSCalendar *calendar = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    return [calendar dateByAddingUnit:unit value:[value integerValue] toDate:self options:0];
}

- (NSDate *)dateByAddingSeconds:(NSNumber *)seconds {
    return [self _addUnit:NSCalendarUnitSecond value:seconds];
}
- (NSDate *)dateByAddingMinutes:(NSNumber *)minutes {
    return [self _addUnit:NSCalendarUnitMinute value:minutes];
}
- (NSDate *)dateByAddingHours:(NSNumber *)hours {
    return [self _addUnit:NSCalendarUnitHour value:hours];
}
- (NSDate *)dateByAddingDays:(NSNumber *)days {
    return [self _addUnit:NSCalendarUnitDay value:days];
}
- (NSDate *)dateByAddingMonths:(NSNumber *)months {
    return [self _addUnit:NSCalendarUnitMonth value:months];
}
- (NSDate *)dateByAddingYears:(NSNumber *)years {
    return [self _addUnit:NSCalendarUnitYear value:years];
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

- (dispatch_queue_t)Extras_trampolineQ {
    @synchronized (self) {
        dispatch_queue_t q = objc_getAssociatedObject(self, @"Extras_trampolineQ");
        if (!q) {
            q = dispatch_queue_create(NULL, NULL);
            objc_setAssociatedObject(self, "Extras_trampolineQ", q, OBJC_ASSOCIATION_RETAIN);
        }
        return q;
    }
}

- (void)performBlock:(dispatch_block_t)block completion:(dispatch_block_t)completion {
    dispatch_async([self Extras_trampolineQ], ^{
        [self performBlockAndWait:block];
        if (completion) completion();
    });
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

- (void)batchDeleteEntitiesWithRequest:(NSFetchRequest *)request error:(NSError * __autoreleasing *)error
{
    if ([NSBatchDeleteRequest class]) {
        // 10.11/iOS 9 path
        NSBatchDeleteRequest *batch = [[NSBatchDeleteRequest alloc] initWithFetchRequest:request];
        [self executeRequest:batch error:error];
    } else {
        // 10.10 path
        for (NSManagedObject *obj in [self executeFetchRequest:request error:error]) {
            [self deleteObject:obj];
        }
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

- (void)mergeAttributesFromDictionary:(NSDictionary *)d {
    NSDictionary *attributes = self.entity.attributesByName;
    for (NSString *key in [attributes allKeys]) {
        NSAttributeDescription *desc = attributes[key];
        NSString *dictKey = desc.userInfo[@"jsonKey"];
        if (!dictKey) dictKey = key;
        id val = nil;
        if ([key isEqualToString:@"rawJSON"]) {
            val = [NSJSONSerialization dataWithJSONObject:d options:0 error:NULL];
        } else {
            val = d[dictKey];
        }
        if ([val isKindOfClass:[NSString class]] && [desc attributeType] == NSDateAttributeType) {
            val = [NSDate dateWithJSONString:val];
        }
        if (val == nil) val = desc.defaultValue;
        if (val == [NSNull null]) val = nil;
        [self setValue:val forKey:key];
    }
}

@end

@implementation SerializedManagedObjectContext {
#ifdef DEBUG
    dispatch_queue_t _myq;
#endif
}

- (id)initWithConcurrencyType:(NSManagedObjectContextConcurrencyType)ct {
    if (self = [super initWithConcurrencyType:ct]) {
#ifdef DEBUG
        [self performBlockAndWait:^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            _myq = dispatch_get_current_queue();
#pragma diagnostic pop
        }];
#endif
    }
    return self;
}

- (void)assertConfinementQueue {
#ifdef DEBUG
    dispatch_queue_t expected = _myq;
    if (expected) {
        dispatch_assert_current_queue(expected);
    }
#endif
}

- (NSArray *)executeFetchRequest:(NSFetchRequest *)request error:(NSError *__autoreleasing *)error {
    [self assertConfinementQueue];
    return [super executeFetchRequest:request error:error];
}

- (BOOL)save:(NSError *__autoreleasing *)error {
    [self assertConfinementQueue];
    return [super save:error];
}

@end

@implementation SerializedManagedObject

- (void)willAccessValueForKey:(NSString *)key {
    id moc = [self managedObjectContext];
    if ([moc isKindOfClass:[SerializedManagedObjectContext class]]) {
        [moc assertConfinementQueue];
    }
    [super willAccessValueForKey:key];
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
            if ([output write:outb maxLength:have] != have) {
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

@implementation NSNumberFormatter (Extras)

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
    myAttrs[NSForegroundColorAttributeName] = [UIColor extras_controlBlue];
#else
    myAttrs[NSForegroundColorAttributeName] = [NSColor extras_controlBlue];
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

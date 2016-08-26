//
//  FoundationExtras.h
//  Ship
//
//  Created by James Howard on 9/12/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <CoreGraphics/CoreGraphics.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#else
#import <AppKit/AppKit.h>
#endif

@interface NSObject (Extras)

- (void)sendAction:(SEL)action toTarget:(id)target;
@property (strong, setter=extras_setRepresentedObject:) id extras_representedObject;

@end

@interface NSString (Extras)

- (NSString *)stringByRemovingSuffix:(NSString *)suffix;
- (NSString *)PascalCase;
- (NSString *)trim;
- (NSString *)urlencode;
- (NSString *)reverse;
- (uint64_t)uint64Value;
+ (NSString *)stringWithHexBytes:(const uint8_t *)b length:(NSUInteger)bLen;

- (BOOL)isDigits; // returns YES if the string is entirely digits
- (BOOL)isUUID;

- (NSData *)dataFromHexString;

+ (NSComparator)comparatorWithOptions:(NSStringCompareOptions)options;

- (BOOL)validateEmail;

- (NSString *)stringByCollapsingNewlines; // replace one or more newlines with a single space.

@end

@interface NSDateFormatter (Extras)

+ (NSDateFormatter *)ISO8601Formatter;
+ (NSDateFormatter *)ISO8601FormatterNoFractionalSeconds;
+ (NSDateFormatter *)shortDateAndTimeFormatter;
+ (NSDateFormatter *)longDateAndTimeFormatter;
+ (NSDateFormatter *)shortDateFormatter;
+ (NSDateFormatter *)shortRelativeDateFormatter;

@end

@interface NSNumberFormatter (Extras)

+ (NSNumberFormatter *)positiveAndNegativeIntegerFormatter; // Positive numbers appear as 123456789, negative appear in red as (123456789)
+ (NSNumberFormatter *)positiveOnlyIntegerFormatter; // i<=0 => "", i > 0 => i

@end

@interface NSDate (Extras)

+ (NSDate *)dateWithJSONString:(NSString *)date;
- (NSString *)JSONString;

- (NSString *)shortUserInterfaceString;
- (NSString *)longUserInterfaceString;

- (NSDate *)dateByAddingTimeIntervalNumber:(NSNumber *)timeInterval;

- (NSDate *)dateByAddingSeconds:(NSNumber *)seconds;
- (NSDate *)dateByAddingMinutes:(NSNumber *)minutes;
- (NSDate *)dateByAddingHours:(NSNumber *)hours;
- (NSDate *)dateByAddingDays:(NSNumber *)days;
- (NSDate *)dateByAddingMonths:(NSNumber *)months;
- (NSDate *)dateByAddingYears:(NSNumber *)years;

- (BOOL)between:(NSDate *)start :(NSDate *)end;

@end

@interface NSMutableDictionary (Extras)

- (void)setOptional:(id)optional forKey:(id<NSCopying>)key;

- (void)filterUsingBlock:(BOOL (^)(id<NSCopying> key, id value))block;

- (void)mapValues:(id (^)(id<NSCopying> key, id value))block;

@end

@interface NSDictionary (Extras)

+ (NSDictionary *)dictionaryWithJSONData:(NSData *)data;
- (NSData *)JSONRepresentation;
- (NSString *)JSONStringRepresentation;

+ (NSDictionary *)lookupWithObjects:(NSArray *)objects keyPath:(NSString *)keyPath;

- (NSDictionary *)dictionaryByAddingEntriesFromDictionary:(NSDictionary *)newDict;

@end

@interface NSData (Extras)

- (NSData *)inflate;
- (NSData *)deflate;

- (NSString *)MD5String;
- (NSString *)SHA1String;

@end

@interface NSArray (Extras)

- (NSArray *)arrayByMappingObjects:(id (^)(id obj))transformer;
- (BOOL)containsObjectMatchingPredicate:(NSPredicate *)predicate;
- (id)firstObjectMatchingPredicate:(NSPredicate *)predicate;

- (NSArray *)filteredArrayUsingPredicate:(NSPredicate *)predicate limit:(NSUInteger)limit;

- (NSArray *)partitionByKeyPath:(NSString *)keyPath; // returns an array of arrays, where self is partitioned by key path

- (NSComparisonResult)localizedStandardCompareContents:(NSArray *)other;

@end

@interface NSMutableArray (Extras)

- (void)moveItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSInteger)idx;

@end

@interface NSSet (Extras)

- (NSSet *)setByMappingObjects:(id (^)(id obj))transformer;

@end

@interface NSOrderedSet (Extras)

- (NSOrderedSet *)orderedSetByMappingObjects:(id (^)(id obj))transformer;

@end

@interface NSPredicate (Extras)

- (NSPredicate *)and:(NSPredicate *)predicate;
- (NSPredicate *)or:(NSPredicate *)predicate;

@end

@interface NSManagedObjectContext (Extras)

- (void)performBlock:(dispatch_block_t)block completion:(dispatch_block_t)completion;

// The following methods must be called within a queue managed by the NSManagedObjectContext

- (void)purge; // removes all entities and calls save:

- (BOOL)batchDeleteEntitiesWithRequest:(NSFetchRequest *)request error:(NSError * __autoreleasing *)error; // removes entities described by request. does not call save:


@end

@interface NSManagedObject (Extras)

- (NSDictionary *)allAttributeValues;
- (void)mergeAttributesFromDictionary:(NSDictionary *)d;
- (void)mergeAttributesFromDictionary:(NSDictionary *)d onlyIfChanged:(BOOL)onlyIfChanged;

- (void)setValue:(id)value forKey:(NSString *)key onlyIfChanged:(BOOL)onlyIfChanged;

@end

// Enforces that all actions are performed within a performBlock context
@interface SerializedManagedObjectContext : NSManagedObjectContext

@end

// Enforces that usage of a managed object does not escape its SerializedManagedObjectContext's private queue
@interface SerializedManagedObject : NSManagedObject

@end

typedef NS_ENUM(NSInteger, CoreDataModificationType) {
    CoreDataModificationTypeInserted,
    CoreDataModificationTypeUpdated,
    CoreDataModificationTypeDeleted,
};

@interface NSNotification (CoreDataExtras)

- (void)enumerateModifiedObjects:(void (^)(id obj, CoreDataModificationType modType, BOOL *stop))block;

@end

BOOL NSRangeContainsRange(NSRange outer, NSRange inner);
BOOL NSRangeIntersectsRange(NSRange a, NSRange b);

CGRect CenteredRectInRect(CGRect outer, CGRect rectToCenter);
CGRect IntegralRect(CGRect r);

void Extras_dispatch_assert_current_queue(dispatch_queue_t q);
#ifndef dispatch_assert_current_queue
#define dispatch_assert_current_queue Extras_dispatch_assert_current_queue
#endif

void RunOnMain(dispatch_block_t);

@interface NSString (Extras_FileTypes)

- (NSString *)mimeTypeFromUTI;
- (NSString *)UTIFromMimeType;
- (NSString *)UTIFromFilename;
- (NSString *)UTIFromExtension;
- (NSString *)extensionFromUTI;

- (BOOL)isImageMimeType;
- (BOOL)isAVMimeType;
- (BOOL)isImageUTI;
- (BOOL)isAVUTI;

@end

@interface NSFileWrapper (Extras)

- (NSString *)uniformTypeIdentifier;
- (NSString *)mimeType;
- (BOOL)isImageType;
- (BOOL)isAVType;

@end

@interface NSIndexSet (Extras)

- (NSUInteger)anyIndex;

@end

@interface NSOutputStream (Extras)

- (BOOL)writeData:(NSData *)data;
- (BOOL)write:(const uint8_t *)bytes length:(NSInteger)length;

@end

@interface NSFileManager (Extras)

- (NSString *)sha1:(NSString *)filePath error:(NSError **)error;
- (NSString *)md5:(NSString *)filePath error:(NSError **)error;

@end

@interface NSProgress (Extras)

+ (NSProgress *)indeterminateProgress;

@end

@interface NSUUID (Extras)

- (NSString *)shortString;
- (id)initWithShortString:(NSString *)str;

@end

@interface BooleanFormatter : NSFormatter

@end

@interface BooleanDotFormatter : NSFormatter

@end

@interface NSMutableAttributedString (Extras)

- (void)appendAttributes:(NSDictionary *)attributes format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

@end

@interface NSAttributedString (Extras)

- (BOOL)hasContents;

- (NSString *)html;
- (NSString *)rtf;
- (NSString *)plainText;

+ (NSAttributedString *)attributedStringWithRTFString:(NSString *)rtf;
+ (NSAttributedString *)attributedStringWithHTMLString:(NSString *)html;
+ (NSAttributedString *)attributedStringWithPlainText:(NSString *)plainText;

+ (NSDictionary *)defaultAttributes;

- (NSRange)rangeOfTextAttachment:(NSTextAttachment *)attachment;

- (NSAttributedString *)scaleFontSizesBy:(CGFloat)scale;

- (NSAttributedString *)trimTrailingWhitespace;

// Used to replace occurrences of NSAttachmentCharacter with to act
// as a placeholder.
+ (NSString *)attachmentPlaceholderCharacterAsString;

@end

@interface NSTimer (WeakTimer)

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti weakTarget:(id)aTarget selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)yesOrNo;

@end

@interface URLSessionResult : NSObject

@property NSURLResponse *response;
@property NSData *data;
@property NSError *error;

@property (nonatomic, readonly) id json;

+ (NSError *)anyErrorInResults:(NSArray<URLSessionResult *> *)results;

@end

@interface NSURLSession (ParallelExtras)

// Perform multiple requests in parallel, and deliver completion once all individual tasks have completed.
- (NSArray *)dataTasksWithRequests:(NSArray<NSURLRequest *> *)requests completion:(void (^)(NSArray<URLSessionResult *> *))completion;

@end

@interface NSURLSessionTask (ProgressExtras)

- (NSProgress *)downloadProgress;

@end

@interface NSError (Extras)

- (BOOL)isCancelError; // returns YES if this is a foundation level cancel error { NSURLErrorDomain, NSURLErrorCancelled }

@end

@interface NSHTTPURLResponse (Extras)

- (BOOL)isSuccessStatusCode;

@end

@interface NSURLComponents (Extras)

@property (nonatomic) NSDictionary *queryItemsDictionary;

@end

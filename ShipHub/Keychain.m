//
//  Keychain.m
//  Ship
//
//  Created by James Howard on 6/16/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

// Loosely derived from BMCredentials by Adam Iredale
// https://github.com/iosengineer/BMCredentials

#import "Keychain.h"

NSString *const KeychainErrorDomain = @"Keychain";

@interface KeychainItem ()

- (BOOL)store:(NSError *__autoreleasing *)error;
- (BOOL)load:(NSError *__autoreleasing *)error;

@property (copy) NSString *service;
@property (copy) NSString *accessGroup;

@end

@implementation KeychainItem

- (BOOL)isEqual:(id)object {
    if (object == self)
    {
        return YES;
    }
    
    if (![object isKindOfClass:[self class]])
    {
        return NO;
    }
    
    KeychainItem *obj = object;
    
    return
    [_account isEqual:obj.account] &&
    [_service isEqual:obj.service] &&
    ((_accessGroup == nil && obj.accessGroup == nil) || [_accessGroup isEqual:obj.accessGroup]) &&
    [_password isEqual:obj.password] &&
    ((_applicationData == nil && obj.applicationData == nil) || ([_applicationData isEqual:obj.applicationData]));
}

- (BOOL)store:(NSError *__autoreleasing *)error {
    NSParameterAssert(_account);
    NSParameterAssert(_service);
    NSParameterAssert(_password);
    
    NSData *secret = [_password dataUsingEncoding:NSUTF8StringEncoding];
    
    // If we have one already, grab it so we can update it
    
    NSMutableDictionary *query =
    [@{
      (__bridge id)kSecClass                : (__bridge id)kSecClassGenericPassword,
      (__bridge id)kSecAttrAccount          : _account,
      (__bridge id)kSecAttrService          : _service,
      (__bridge id)kSecReturnAttributes     : @YES
      } mutableCopy];
    
    NSMutableDictionary *payload =
    [@{
      (__bridge id)kSecAttrAccount          : _account,
      (__bridge id)kSecAttrService          : _service,
      (__bridge id)kSecValueData            : secret,
      } mutableCopy];
    
    if (_accessGroup) {
        query[(__bridge id)kSecAttrAccessGroup] = _accessGroup;
        payload[(__bridge id)kSecAttrAccessGroup] = _accessGroup;
    }
    
    if (_applicationData) {
        payload[(__bridge id)kSecAttrGeneric] = _applicationData;
    }
    
    OSStatus findStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    
    if (findStatus == errSecSuccess) {
        // Existing one found. Delete it.
        // Do not update them due to: http://arxiv.org/abs/1505.06836
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
        
        if (status != errSecSuccess)
        {
            // We have a problem
            if (error)
            {
                *error = [NSError errorWithDomain:KeychainErrorDomain code:status userInfo:nil];
            }
            return NO;
        } else {
            findStatus = errSecItemNotFound;
        }
    }
    
    if (findStatus == errSecItemNotFound)
    {
        // None found. Add a new one
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        [attributes addEntriesFromDictionary:query];
        [attributes addEntriesFromDictionary:payload];
        
#if TARGET_OS_IOS
        // Make sure that the item is accessible in the background.
        // If not, background app refresh may fail.
        // See: http://stackoverflow.com/questions/5392988/default-ksecattraccessible-value-for-keychain-items
        attributes[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
#endif
        
        [attributes removeObjectForKey:(__bridge id)kSecReturnAttributes];
        
        OSStatus status = SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
        
        if (status != errSecSuccess)
        {
            if (error)
            {
                *error = [NSError errorWithDomain:KeychainErrorDomain code:status userInfo:nil];
            }
            return NO;
        }
        
    }
    else
    {
        // Errrk! Error.
        if (error)
        {
            *error = [NSError errorWithDomain:KeychainErrorDomain code:findStatus userInfo:nil];
        }
        return NO;
    }
    return YES;
}

- (BOOL)load:(NSError *__autoreleasing *)error {
    NSParameterAssert(_account);
    NSParameterAssert(_service);
    
    NSMutableDictionary *query =
    [@{
      (__bridge id)kSecClass                : (__bridge id)kSecClassGenericPassword,
      (__bridge id)kSecAttrAccount          : _account,
      (__bridge id)kSecAttrService          : _service,
      (__bridge id)kSecReturnData           : @YES,
      (__bridge id)kSecReturnAttributes     : @YES
      } mutableCopy];
    
    if (_accessGroup) {
        query[(__bridge id)kSecAttrAccessGroup] = _accessGroup;
    }
    
    CFTypeRef outTypeRef;
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &outTypeRef);
    
    if (status == errSecSuccess)
    {
        // Load up!
        
        NSDictionary *itemInfo = (__bridge NSDictionary *)(outTypeRef);
        
        self.applicationData = itemInfo[(__bridge id)kSecAttrGeneric];
        self.password = [[NSString alloc] initWithData:itemInfo[(__bridge id)kSecValueData]
                                              encoding:NSUTF8StringEncoding];
        
#if TARGET_OS_IOS
        NSString *currentAccessibility = itemInfo[(__bridge id)kSecAttrAccessible];
        if (!currentAccessibility || ![currentAccessibility isEqualToString:(__bridge NSString *)kSecAttrAccessibleAfterFirstUnlock])
        {
            DebugLog(@"Must update accessibility. Was %@. Will be %@", currentAccessibility, (__bridge id)kSecAttrAccessibleAfterFirstUnlock);
            NSError *storeErr = nil;
            [self store:&storeErr];
            if (storeErr) {
                ErrLog(@"Error updating accessibility: %@", storeErr);
            }
        }
#endif
        
        CFRelease(outTypeRef);
        
        return YES;
    }
    else
    {
        // Either not found or error
        if (error)
        {
            *error = [NSError errorWithDomain:KeychainErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
}

@end

@implementation Keychain

- (instancetype)initWithService:(NSString *)service accessGroup:(NSString *)accessGroup {
    NSParameterAssert(service);
    if (self = [super init]) {
        _service = [service copy];
        _accessGroup = [accessGroup copy];
    }
    return self;
}

- (instancetype)init {
    NSAssert(NO, @"-initWithService:accessGroup: is the designated initializer");
    return nil;
}

- (NSArray *)allAccountsReturningError:(NSError *__autoreleasing *)error {
    NSMutableDictionary *query =
    [@{
      (__bridge id)kSecClass                : (__bridge id)kSecClassGenericPassword,
      (__bridge id)kSecReturnAttributes     : @YES,
      (__bridge id)kSecMatchLimit           : (__bridge id)kSecMatchLimitAll
      } mutableCopy];

    if (_accessGroup) {
        query[(__bridge id)kSecAttrAccessGroup] = _accessGroup;
    }
//    if (_service) {
//        query[(__bridge id)kSecAttrService] = _service;
//    }
    
    CFArrayRef array = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)(&array));
    
    if (status == errSecSuccess || status == errSecItemNotFound) {
        if (array) {
            // For some reason, specifying the service will end up with no results being returned.
            // So just filter it here.
            NSArray *filtered = [(__bridge NSArray *)array filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"%K == %@", (__bridge id)kSecAttrService, _service]];
            
            // Sort them so newest items are first
            NSArray *sorted = [filtered sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
                NSDate *modified1 = obj1[(__bridge id)kSecAttrModificationDate];
                NSDate *modified2 = obj2[(__bridge id)kSecAttrModificationDate];
                
                if (!modified1 && !modified2) {
                    return NSOrderedSame;
                } else if (modified1 && !modified2) {
                    return NSOrderedAscending;
                } else if (!modified1 && modified2) {
                    return NSOrderedDescending;
                } else {
                    return [modified2 compare:modified1]; // reverse the compare so newest is first
                }
            }];
            
            NSMutableArray *results = [NSMutableArray arrayWithCapacity:[sorted count]];
            for (NSDictionary *attrs in sorted) {
                NSString *account = attrs[(__bridge id)kSecAttrAccount];
                if (account) {
                    [results addObject:account];
                }
            }
            CFRelease(array);
            return results;
        } else {
            return @[];
        }
    } else {
        // A real error
        if (error)
        {
            *error = [NSError errorWithDomain:KeychainErrorDomain code:status userInfo:nil];
        }
        return nil;
    }
}

- (BOOL)removeAllItemsReturningError:(NSError *__autoreleasing *)error {
    NSMutableDictionary *query =
    [@{
      (__bridge id)kSecClass                : (__bridge id)kSecClassGenericPassword,
      (__bridge id)kSecAttrService          : _service,
      (__bridge id)kSecReturnData           : @NO
      } mutableCopy];
    
    if (_accessGroup) {
        query[(__bridge id)kSecAttrAccessGroup] = _accessGroup;
    }
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    
    if (status == errSecSuccess || status == errSecItemNotFound)
    {
        // Deleted or didn't exist
        return YES;
    }
    else
    {
        // A real error
        if (error)
        {
            *error = [NSError errorWithDomain:KeychainErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
}

- (BOOL)removeItemForAccount:(NSString *)account error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(account);
    
    NSMutableDictionary *query =
    [@{
      (__bridge id)kSecClass                : (__bridge id)kSecClassGenericPassword,
      (__bridge id)kSecAttrAccount          : account,
      (__bridge id)kSecAttrService          : _service,
      (__bridge id)kSecReturnData           : @NO
      } mutableCopy];
    
    if (_accessGroup) {
        query[(__bridge id)kSecAttrAccessGroup] = _accessGroup;
    }
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    
    if (status == errSecSuccess || status == errSecItemNotFound)
    {
        // Deleted or didn't exist
        return YES;
    }
    else
    {
        // A real error
        if (error)
        {
            *error = [NSError errorWithDomain:KeychainErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
}

- (BOOL)storeItem:(KeychainItem *)item error:(NSError *__autoreleasing *)error {
    NSParameterAssert(item);
    item.service = _service;
    item.accessGroup = _accessGroup;
    return [item store:error];
}

- (KeychainItem *)itemForAccount:(NSString *)account error:(NSError *__autoreleasing *)error {
    NSParameterAssert(account);
    
    KeychainItem *item = [KeychainItem new];
    item.account = account;
    item.service = _service;
    item.accessGroup = _accessGroup;
    
    if ([item load:error]) {
        return item;
    } else {
        return nil;
    }
}

@end


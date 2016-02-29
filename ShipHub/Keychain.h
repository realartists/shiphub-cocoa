//
//  Keychain.h
//  Ship
//
//  Created by James Howard on 6/16/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeychainItem : NSObject

@property (copy) NSString *account;     // required
@property (copy) NSString *password;    // required

@property (copy) NSData *applicationData; // optional, defaults to nil

@end

@interface Keychain : NSObject

- (instancetype)initWithService:(NSString *)service accessGroup:(NSString *)accessGroup; // Designated initializer

@property (readonly, copy) NSString *service;
@property (readonly, copy) NSString *accessGroup;

- (NSArray *)allAccountsReturningError:(NSError *__autoreleasing *)error;
- (BOOL)removeAllItemsReturningError:(NSError *__autoreleasing *)error;

- (BOOL)removeItemForAccount:(NSString *)account error:(NSError *__autoreleasing *)error;

- (BOOL)storeItem:(KeychainItem *)item error:(NSError *__autoreleasing *)error;
- (KeychainItem *)itemForAccount:(NSString *)account error:(NSError *__autoreleasing *)error;

@end

extern NSString *const KeychainErrorDomain;

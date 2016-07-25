//
//  Keychain.h
//  Ship
//
//  Created by James Howard on 6/16/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface KeychainItem : NSObject

@property (copy) NSString *server;      // required
@property (copy) NSString *account;     // required
@property (copy) NSString *password;    // required

@property (copy) NSData *applicationData; // optional, defaults to nil

@end

@interface Keychain : NSObject

- (instancetype)initWithServicePrefix:(NSString *)service accessGroup:(NSString *)accessGroup; // Designated initializer

@property (readonly, copy) NSString *servicePrefix;
@property (readonly, copy) NSString *accessGroup;

- (NSArray<KeychainItem *> *)allAccountsReturningError:(NSError *__autoreleasing *)error; // Returns KeychainItems with server and account populated, but password and applicationData will be nil. To fetch that info, use itemForAccount:server:error:.

- (BOOL)removeItemForAccount:(NSString *)account server:(NSString *)server error:(NSError *__autoreleasing *)error;

- (BOOL)storeItem:(KeychainItem *)item error:(NSError *__autoreleasing *)error;

- (KeychainItem *)itemForAccount:(NSString *)account server:(NSString *)server error:(NSError *__autoreleasing *)error;

@end

extern NSString *const KeychainErrorDomain;

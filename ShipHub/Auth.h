//
//  Auth.h
//  ShipHub
//
//  Created by James Howard on 2/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "JSONItem.h"

@class ServerConnection;

@interface AuthAccount : NSObject <JSONItem>

@property (copy) NSString *login;
@property (copy) NSString *name;
@property (strong) NSNumber *identifier;

@property (strong) NSDictionary *extra;

@end

typedef void (^AuthTwoFactorContinuation)(NSString *twoFactorToken); // pass nil to abort
typedef void (^AuthChooseReposContinuation)(ServerConnection *conn, AuthAccount *account, NSArray *repos, dispatch_block_t commit);

typedef NS_ENUM(NSInteger, AuthState) {
    AuthStateInvalid,
    AuthStateValid
};

@interface Auth : NSObject

+ (NSArray<NSString *> *)allLogins;
+ (NSString *)lastUsedLogin;

+ (Auth *)authWithLogin:(NSString *)login;
+ (Auth *)authForPendingLogin;

@property (readonly, strong) AuthAccount *account;
@property (readonly, copy) NSString *token;

@property (readonly) AuthState authState;

- (void)authorizeWithLogin:(NSString *)login
                  password:(NSString *)password
                 twoFactor:(void (^)(AuthTwoFactorContinuation))twoFactorContinuation
               chooseRepos:(AuthChooseReposContinuation)chooseReposContinuation
                completion:(void (^)(NSError *error))completion;

@end

extern NSString *const AuthStateChangedNotification;
extern NSString *const AuthStateKey;
extern NSString *const AuthStatePreviousKey;

//
//  Error.h
//  Ship
//
//  Created by James Howard on 5/21/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const ShipErrorDomain;
extern NSString *const ShipErrorUserInfoProblemIDKey;

extern NSString *const ShipErrorUserInfoConflictsKey;
extern NSString *const ShipErrorUserInfoLocalProblemKey;
extern NSString *const ShipErrorUserInfoServerProblemKey;

extern NSString *const ShipErrorUserInfoHTTPResponseCodeKey;
extern NSString *const ShipErrorUserInfoErrorJSONBodyKey;

typedef NS_ENUM(NSInteger, ShipErrorCode) {
    ShipErrorCodeUnexpectedServerResponse = 1,
    ShipErrorCodeProblemDoesNotExist = 5,
    ShipErrorCodeProblemSaveConflict = 6,
    ShipErrorCodeNeedsAuthToken = 7,
    ShipErrorCodeExpiredOneTimeAuthToken = 8,
    ShipErrorCodeIncompatibleQuery = 9,
    ShipErrorCodeInvalidSignUpDetails = 10,
    ShipErrorCodeInvalidQuery = 11,
    ShipErrorCodeInvalidPassword = 12,
    ShipErrorCodeInvalidUserAccount = 13,
    ShipErrorCodeProblemSaveOtherError = 14,
    ShipErrorCodeInternalInconsistencyError = 15,
    ShipErrorCodeGitCloneError = 16,
    ShipErrorCodeCannotMergePRError = 17,
    ShipErrorCodeCannotUpdatePRBranchError = 18
};

NSString *ShipErrorLocalizedDescriptionForCode(ShipErrorCode code);

@interface NSError (ShipError)

+ (NSError *)shipErrorWithCode:(ShipErrorCode)code;
+ (NSError *)shipErrorWithCode:(ShipErrorCode)code userInfo:(NSDictionary *)userInfo;
+ (NSError *)shipErrorWithCode:(ShipErrorCode)code localizedMessage:(NSString *)message;

@property (nonatomic, readonly, getter=isShipError) BOOL shipError;

- (NSInteger)shipHttpErrorCode;

@end

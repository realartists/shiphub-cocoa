//
//  Error.h
//  Ship
//
//  Created by James Howard on 5/21/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *ShipErrorDomain;
extern NSString *ShipErrorUserInfoProblemIDKey;

extern NSString *ShipErrorUserInfoConflictsKey;
extern NSString *ShipErrorUserInfoLocalProblemKey;
extern NSString *ShipErrorUserInfoServerProblemKey;

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
};

NSString *ShipErrorLocalizedDescriptionForCode(ShipErrorCode code);


@interface NSError (ShipError)

+ (NSError *)shipErrorWithCode:(ShipErrorCode)code;
+ (NSError *)shipErrorWithCode:(ShipErrorCode)code localizedMessage:(NSString *)message;

@property (nonatomic, readonly, getter=isShipError) BOOL shipError;

@end

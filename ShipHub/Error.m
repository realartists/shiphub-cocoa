//
//  Error.m
//  Ship
//
//  Created by James Howard on 5/21/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "Error.h"

NSString *ShipErrorDomain = @"ShipErrorDomain";
NSString *ShipErrorUserInfoProblemIDKey= @"ProblemID";

NSString *ShipErrorUserInfoConflictsKey = @"Conflicts";
NSString *ShipErrorUserInfoLocalProblemKey = @"LocalProblem";
NSString *ShipErrorUserInfoServerProblemKey = @"ServerProblem";


NSString *ShipErrorLocalizedDescriptionForCode(ShipErrorCode code) {
    switch (code) {
        case ShipErrorCodeProblemDoesNotExist: return NSLocalizedString(@"The requested problem does not exist.", nil);
        case ShipErrorCodeUnexpectedServerResponse: return NSLocalizedString(@"The server returned an unexpected response.", nil);
        case ShipErrorCodeNeedsAuthToken: return NSLocalizedString(@"You must be logged in to perform this action.", nil);
        case ShipErrorCodeProblemSaveConflict: return NSLocalizedString(@"Save conflict.", nil);
        case ShipErrorCodeExpiredOneTimeAuthToken: return NSLocalizedString(@"The link has expired. Please request a new email.", nil);
        case ShipErrorCodeIncompatibleQuery: return NSLocalizedString(@"The provided query is incompatible with the requested operation.", nil);
        case ShipErrorCodeInvalidSignUpDetails: return NSLocalizedString(@"Unable to sign up.", nil);
        case ShipErrorCodeInvalidQuery: return NSLocalizedString(@"Unable to run the provided query. Make sure you have the latest version of Ship installed.", nil);
        case ShipErrorCodeInvalidPassword: return NSLocalizedString(@"Invalid login or password", nil);
        case ShipErrorCodeInvalidUserAccount: return NSLocalizedString(@"Invalid or non-existent account", nil);
        default: return NSLocalizedString(@"Unexpected Error", nil);
    }
}

@implementation NSError (ShipError)

+ (NSError *)shipErrorWithCode:(ShipErrorCode)code {
    return [self shipErrorWithCode:code problemID:nil];
}
+ (NSError *)shipErrorWithCode:(ShipErrorCode)code problemID:(NSNumber *)problemID
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = ShipErrorLocalizedDescriptionForCode(code);
    if (problemID) {
        userInfo[ShipErrorUserInfoProblemIDKey] = problemID;
    }
    return [NSError errorWithDomain:ShipErrorDomain code:code userInfo:userInfo];
}

+ (NSError *)shipErrorWithCode:(ShipErrorCode)code localizedMessage:(NSString *)message {
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    userInfo[NSLocalizedDescriptionKey] = message ?: ShipErrorLocalizedDescriptionForCode(code);
    return [NSError errorWithDomain:ShipErrorDomain code:code userInfo:userInfo];
}

- (BOOL)isShipError {
    return [[self domain] isEqualToString:ShipErrorDomain];
}
@end

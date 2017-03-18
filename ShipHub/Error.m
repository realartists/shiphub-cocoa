//
//  Error.m
//  Ship
//
//  Created by James Howard on 5/21/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "Error.h"

NSString *const ShipErrorDomain = @"ShipErrorDomain";
NSString *const ShipErrorUserInfoProblemIDKey= @"ProblemID";

NSString *const ShipErrorUserInfoConflictsKey = @"Conflicts";
NSString *const ShipErrorUserInfoLocalProblemKey = @"LocalProblem";
NSString *const ShipErrorUserInfoServerProblemKey = @"ServerProblem";

NSString *const ShipErrorUserInfoHTTPResponseCodeKey = @"ShipHTTPResponseCode";
NSString *const ShipErrorUserInfoErrorJSONBodyKey = @"ShipErrorUserInfoErrorJSONBody";

NSString *ShipErrorLocalizedDescriptionForCode(ShipErrorCode code) {
    switch (code) {
        case ShipErrorCodeProblemDoesNotExist: return NSLocalizedString(@"The requested issue does not exist.", nil);
        case ShipErrorCodeUnexpectedServerResponse: return NSLocalizedString(@"The server returned an unexpected response.", nil);
        case ShipErrorCodeNeedsAuthToken: return NSLocalizedString(@"You must be logged in to perform this action.", nil);
        case ShipErrorCodeProblemSaveConflict: return NSLocalizedString(@"Save conflict.", nil);
        case ShipErrorCodeExpiredOneTimeAuthToken: return NSLocalizedString(@"The link has expired. Please request a new email.", nil);
        case ShipErrorCodeIncompatibleQuery: return NSLocalizedString(@"The provided query is incompatible with the requested operation.", nil);
        case ShipErrorCodeInvalidSignUpDetails: return NSLocalizedString(@"Unable to sign up.", nil);
        case ShipErrorCodeInvalidQuery: return NSLocalizedString(@"Unable to run the provided query. Make sure you have the latest version of Ship installed.", nil);
        case ShipErrorCodeInvalidPassword: return NSLocalizedString(@"Invalid username or password", nil);
        case ShipErrorCodeInvalidUserAccount: return NSLocalizedString(@"Invalid or non-existent account", nil);
        case ShipErrorCodeProblemSaveOtherError: return NSLocalizedString(@"Unable to save issue", nil);
        case ShipErrorCodeInternalInconsistencyError: return NSLocalizedString(@"Internal inconsistency error. Consider removing the contents of ~/Library/RealArtists and restarting the application.", nil);
        case ShipErrorCodeGitCloneError: return NSLocalizedString(@"Unable to clone the repository", nil);
        case ShipErrorCodeCannotMergePRError: return NSLocalizedString(@"The Pull Request branch cannot be cleanly merged into the default repository branch", nil);
        default: return NSLocalizedString(@"Unexpected Error", nil);
    }
}

@implementation NSError (ShipError)

+ (NSError *)shipErrorWithCode:(ShipErrorCode)code {
    return [self shipErrorWithCode:code problemID:nil];
}
+ (NSError *)shipErrorWithCode:(ShipErrorCode)code userInfo:(NSDictionary *)userInfo {
    return [NSError errorWithDomain:ShipErrorDomain code:code userInfo:userInfo];
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

- (NSInteger)shipHttpErrorCode {
    NSNumber *num = [self userInfo][ShipErrorUserInfoHTTPResponseCodeKey];
    return [num integerValue];
}

@end

//
//  NSString+IssueIdentifier.h
//  ShipHub
//
//  Created by James Howard on 3/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (IssueIdentifier)

+ (NSString *)issueIdentifierWithOwner:(NSString *)ownerLogin repo:(NSString *)repoName number:(NSNumber *)number;

@property (readonly, getter=isIssueIdentifier) BOOL issueIdentifier;

- (NSString *)issueRepoOwner;
- (NSString *)issueRepoName;
- (NSNumber *)issueNumber;

@end

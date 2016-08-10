//
//  IssueWaiter.h
//  ShipHub
//
//  Created by James Howard on 8/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Issue;

@interface IssueWaiter : NSObject

+ (instancetype)waiterForIssueIdentifier:(id)issueIdentifier;

@property (copy, readonly) id issueIdentifier;
@property NSTimeInterval maximumWait; // default is 10s.

// issue argument to completion will be nil if timeout is hit.
- (void)waitForIssue:(void (^)(Issue *issue))completion;

@end

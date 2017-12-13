//
//  RMEPRLoader.h
//  Reviewed By Me
//
//  Created by James Howard on 11/30/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Auth;
@class Issue;

typedef void (^RMEPRLoaderCompletion)(Issue *issue, NSError *error);

@interface RMEPRLoader : NSObject

- (id)initWithIssueIdentifier:(id)issueIdentifier auth:(Auth *)auth queue:(dispatch_queue_t)queue;

@property (copy) RMEPRLoaderCompletion completion;

- (void)start;

@end

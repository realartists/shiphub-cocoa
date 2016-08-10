//
//  IssueWaiter.m
//  ShipHub
//
//  Created by James Howard on 8/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "IssueWaiter.h"

#import "DataStore.h"
#import "Issue.h"

@interface IssueWaiter ()

@property (copy) void (^callback)(Issue *issue);
@property (strong) NSTimer *timer;

@end

@implementation IssueWaiter

+ (instancetype)waiterForIssueIdentifier:(id)issueIdentifier {
    return [[self alloc] initWithIssueIdentifier:issueIdentifier];
}

- (instancetype)initWithIssueIdentifier:(id)issueIdentifier {
    if (self = [super init]) {
        _issueIdentifier = [issueIdentifier copy];
        _maximumWait = 10.0;
    }
    return self;
}

- (void)dealloc {
    Trace();
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)checkNow {
    [[DataStore activeStore] loadFullIssue:_issueIdentifier completion:^(Issue *issue, NSError *error) {
        if (issue) {
            [self completeWithIssue:issue];
        }
    }];
}

- (void)completeWithIssue:(Issue *)issue {
    if (_callback) {
        void (^callback)(Issue *issue) = _callback;
        _callback = nil;
        callback(nil);
    }
    
    [_timer invalidate];
    _timer = nil;
}

- (void)timerFired:(NSTimer *)timer {
    Trace();
    [self completeWithIssue:nil];
}

- (void)didUpdateIssues:(NSNotification *)note {
    NSArray *identifiers = note.userInfo[DataStoreUpdatedProblemsKey];
    if ([identifiers containsObject:_issueIdentifier]) {
        [self checkNow];
    }
}

- (void)waitForIssue:(void (^)(Issue *issue))completion {
    NSParameterAssert(completion);
    NSAssert([NSThread isMainThread], @"Must be on the main thread");
    NSAssert(_callback == nil, @"Cannot already have a callback");
    
    self.callback = completion;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didUpdateIssues:) name:DataStoreDidUpdateProblemsNotification object:nil];
    
    // intentionally create a retain cycle between self and timer
    DebugLog(@"self.maximumWait %f", self.maximumWait);
    self.timer = [NSTimer scheduledTimerWithTimeInterval:self.maximumWait target:self selector:@selector(timerFired:) userInfo:nil repeats:NO];
    
    [self checkNow];
}

@end

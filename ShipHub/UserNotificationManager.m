//
//  UserNotificationManager.m
//  ShipHub
//
//  Created by James Howard on 9/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "UserNotificationManager.h"

#import "Extras.h"
#import "DataStore.h"
#import "Issue.h"
#import "IssueIdentifier.h"
#import "IssueNotification.h"
#import "IssueComment.h"
#import "IssueDocumentController.h"


@interface UserNotificationManager () <NSUserNotificationCenterDelegate>

@property NSDate *lastChecked;
@property dispatch_queue_t q;
@property dispatch_source_t timer;

@end

@implementation UserNotificationManager

+ (UserNotificationManager *)sharedManager {
    static dispatch_once_t onceToken;
    static UserNotificationManager *sharedManager;
    dispatch_once(&onceToken, ^{
        sharedManager = [UserNotificationManager new];
    });
    return sharedManager;
}

- (id)init {
    if (self = [super init]) {
        _lastChecked = [NSDate date];
        _q = dispatch_queue_create("UserNotificationManager", NULL);
        _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _q);
        __weak __typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(_timer, ^{
            id strongSelf = weakSelf;
            [strongSelf _update];
        });
        dispatch_resume(_timer);
        
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(update) name:DataStoreDidUpdateProblemsNotification object:nil];
        [nc addObserver:self selector:@selector(update) name:DataStoreActiveDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(update) name:DataStoreDidChangeReposHidingNotification object:nil];
        
        NSUserNotificationCenter *unc = [NSUserNotificationCenter defaultUserNotificationCenter];
        [unc setDelegate:self];
        
        [self update];
    }
    return self;
}

- (void)dealloc {
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)_update {
    Trace();
    
    [[DataStore activeStore] issuesMatchingPredicate:[NSPredicate predicateWithFormat:@"notification.unread = YES"] sortDescriptors:nil options:@{ IssueOptionIncludeNotification : @YES, IssueOptionIncludeEventsAndComments : @YES } completion:^(NSArray<Issue *> *issues, NSError *error) {
        
        dispatch_async(_q, ^{
            [self updateWithIssues:issues];
        });
    }];
}

- (void)update {
    Trace();
    
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 1 * NSEC_PER_SEC);
}

- (NSString *)titleForIssue:(Issue *)issue {
    IssueNotification *inote = issue.notification;
    if (inote.commentIdentifier) {
        return [NSString stringWithFormat:NSLocalizedString(@"New Comment in %@#%@", nil), [issue.fullIdentifier issueRepoName], issue.number];
    } else if (issue.updatedAt != nil && [issue.updatedAt compare:issue.createdAt] == NSOrderedDescending)
    {
        return [NSString stringWithFormat:NSLocalizedString(@"Issue Updated: %@#%@", nil), [issue.fullIdentifier issueRepoName], issue.number];
    } else {
        return [NSString stringWithFormat:NSLocalizedString(@"New Issue: %@#%@", nil), [issue.fullIdentifier issueRepoName], issue.number];
    }
}

- (void)updateWithIssues:(NSArray<Issue *> *)issues {
    NSUserNotificationCenter *nc = [NSUserNotificationCenter defaultUserNotificationCenter];
    NSArray *delivered = nc.deliveredNotifications;
    NSDictionary *deliveredLookup = [NSDictionary lookupWithObjects:delivered keyPath:@"identifier"];
    NSDictionary *unreadLookup = [NSDictionary lookupWithObjects:issues keyPath:@"fullIdentifier"];
    NSSet *deliveredFullIdentifiers = [NSSet setWithArray:[deliveredLookup allKeys]];
    
    NSSet *unreadIdentifiers = [NSSet setWithArray:[unreadLookup allKeys]];
    
    NSMutableSet *needToAddToNC = [unreadIdentifiers mutableCopy];
    [needToAddToNC minusSet:deliveredFullIdentifiers];
    
    NSMutableSet *needToRemoveFromNC = [deliveredFullIdentifiers mutableCopy];
    [needToRemoveFromNC minusSet:unreadIdentifiers];
    
    for (id issueIdentifier in needToRemoveFromNC) {
        NSUserNotification *note = deliveredLookup[issueIdentifier];
        DebugLog(@"Removing note %@", issueIdentifier);
        [nc removeDeliveredNotification:note];
    }
    
    for (id issueIdentifier in needToAddToNC) {
        NSUserNotification *note = [NSUserNotification new];
        Issue *issue = unreadLookup[issueIdentifier];
        IssueNotification *inote = issue.notification;
        
        note.identifier = issueIdentifier;
        note.actionButtonTitle = NSLocalizedString(@"View", nil);
        note.title = [self titleForIssue:issue];
        note.subtitle = issue.title;
        
        if (inote.commentIdentifier) {
            IssueComment *comment = [[issue.comments filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"identifier = %@", inote.commentIdentifier] limit:1] firstObject];
            note.informativeText = comment.body;
            note.userInfo = @{ @"commentIdentifier" : inote.commentIdentifier };
        }
        if (!note.informativeText) {
            note.informativeText = issue.body;
        }
        
        BOOL shouldPresent = [inote.updatedAt compare:_lastChecked] == NSOrderedDescending;
        
        if (shouldPresent) {
            DebugLog(@"Delivering note %@", note);
            [nc deliverNotification:note];
        } else {
            DebugLog(@"Not delivering note because it's too old: %@", note);
        }
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification
{
    DebugLog(@"%@", notification);
    RunOnMain(^{
        NSNumber *commentIdentifier = notification.userInfo[@"commentIdentifier"];
        [[IssueDocumentController sharedDocumentController] openIssueWithIdentifier:notification.identifier canOpenExternally:NO scrollToCommentWithIdentifier:commentIdentifier completion:nil];
    });
}

- (void)applicationDidLaunch:(NSNotification *)note {
    NSUserNotification *un = note.userInfo[NSApplicationLaunchUserNotificationKey];
    if (un) {
        [self userNotificationCenter:[NSUserNotificationCenter defaultUserNotificationCenter] didDeliverNotification:un];
    }
}

@end

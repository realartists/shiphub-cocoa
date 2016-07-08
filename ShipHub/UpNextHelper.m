//
//  UpNextHelper.m
//  ShipHub
//
//  Created by James Howard on 7/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "UpNextHelper.h"

#import "DataStore.h"
#import "Extras.h"

@implementation UpNextHelper

+ (instancetype)sharedHelper {
    static dispatch_once_t onceToken;
    static UpNextHelper *helper;
    dispatch_once(&onceToken, ^{
        helper = [UpNextHelper new];
    });
    return helper;
}

- (void)addToUpNext:(NSArray<NSString *> *)additions
             atHead:(BOOL)atHead
             window:(NSWindow *)window
         completion:(void (^)(NSError *error))completion
{
    [[DataStore activeStore] addToUpNext:additions atHead:atHead completion:^(NSError *error) {
        if (error) {
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert beginSheetModalForWindow:window completionHandler:nil];
        } else {
            [self validateUpNextAdditions:additions alertWindow:window];
        }
        if (completion) completion(error);
    }];
}

- (void)insertIntoUpNext:(NSArray<NSString *> *)additions
    aboveIssueIdentifier:(NSString *)above
                  window:(NSWindow *)window
              completion:(void (^)(NSError *error))completion
{
    [[DataStore activeStore] insertIntoUpNext:additions aboveIssueIdentifier:above completion:^(NSError *error) {
        if (error) {
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert beginSheetModalForWindow:window completionHandler:nil];
        } else {
            [self validateUpNextAdditions:additions alertWindow:window];
        }
        if (completion) completion(error);
    }];
}

- (void)removeFromUpNext:(NSArray<NSString *> *)removals
                  window:(NSWindow *)window
              completion:(void (^)(NSError *error))completion
{
    [[DataStore activeStore] removeFromUpNext:removals completion:^(NSError *error) {
        if (error) {
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert beginSheetModalForWindow:window completionHandler:nil];
        }
        if (completion) completion(error);
    }];
}

- (void)validateUpNextAdditions:(NSArray<NSString *> *)additions alertWindow:(NSWindow *)window
{
    BOOL disableWarning = [[Defaults defaults] boolForKey:@"DisableWarnUpNextClosedState"];
    if (!disableWarning) {
        DataStore *store = [DataStore activeStore];
        [store countIssuesMatchingPredicate:[[store predicateForIssueIdentifiers:additions] and:[NSPredicate predicateWithFormat:@"closed = YES"]] completion:^(NSUInteger count, NSError *error) {
            if (count > 0) {
                NSAlert *alert = [NSAlert new];
                alert.messageText = NSLocalizedString(@"Closed issues are not shown in Up Next.", nil);
                alert.informativeText = NSLocalizedString(@"Closed issues can be added to your Up Next queue, but they will not be shown unless they are re-opened.", nil);
                alert.showsSuppressionButton = YES;
                [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
                [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse returnCode) {
                    [[Defaults defaults] setBool:alert.suppressionButton.state == NSOnState forKey:@"DisableWarnUpNextClosedState"];
                }];
            }
        }];
    }
}

@end

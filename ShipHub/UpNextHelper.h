//
//  UpNextHelper.h
//  ShipHub
//
//  Created by James Howard on 7/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UpNextHelper : NSObject

+ (instancetype)sharedHelper;

- (void)addToUpNext:(NSArray<NSString *> *)additions
             atHead:(BOOL)atHead
             window:(NSWindow *)window
         completion:(void (^)(NSError *error))completion;

- (void)insertIntoUpNext:(NSArray<NSString *> *)additions
    aboveIssueIdentifier:(NSString *)above
                  window:(NSWindow *)window
              completion:(void (^)(NSError *error))completion;

- (void)removeFromUpNext:(NSArray<NSString *> *)removals
                  window:(NSWindow *)window
              completion:(void (^)(NSError *error))completion;

- (void)validateUpNextAdditions:(NSArray<NSString *> *)additions alertWindow:(NSWindow *)window;

@end

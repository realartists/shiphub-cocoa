//
//  BulkModifyHelper.h
//  ShipHub
//
//  Created by James Howard on 7/26/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Issue;

@interface BulkModifyHelper : NSObject

+ (instancetype)sharedHelper;

// Used for drag and drop
- (void)moveIssues:(NSArray<NSString *> *)issueIdentifiers toMilestone:(NSString *)milestoneTitle window:(NSWindow *)window completion:(void (^)(NSError *error))completion;

- (void)editMilestone:(NSArray<Issue *> *)issues window:(NSWindow *)window;
- (void)editLabels:(NSArray<Issue *> *)issues window:(NSWindow *)window;
- (void)editAssignees:(NSArray<Issue *> *)issues window:(NSWindow *)window;
- (void)editState:(NSArray<Issue *> *)issues window:(NSWindow *)window;

@end

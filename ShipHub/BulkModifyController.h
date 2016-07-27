//
//  BulkModifyController.h
//  ShipHub
//
//  Created by James Howard on 7/27/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Issue;
@protocol BulkModifyDelegate;

@interface BulkModifyController : NSViewController

- (id)initWithIssues:(NSArray<Issue *> *)issues;

@property (readonly) NSArray<Issue *> *issues;

@property (weak) id<BulkModifyDelegate> delegate;

@end

@protocol BulkModifyDelegate <NSObject>

- (void)bulkModifyDidCancel:(BulkModifyController *)controller;
- (void)bulkModifyDidBegin:(BulkModifyController *)controller;
- (void)bulkModifyDidEnd:(BulkModifyController *)controller error:(NSError *)error;

@end

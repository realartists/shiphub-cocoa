//
//  SearchSheet.h
//  ShipHub
//
//  Created by James Howard on 7/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CustomQuery;

@interface SearchSheet : NSWindowController

@property (nonatomic, strong) CustomQuery *query;

- (void)beginSheetModalForWindow:(NSWindow *)sheetWindow completionHandler:(void (^)(CustomQuery *query))handler;

@end

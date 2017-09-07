//
//  WebFindBarController.h
//  ShipHub
//
//  Created by James Howard on 3/21/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol WebFindBarControllerDelegate;

@interface WebFindBarController : NSViewController

- (void)performFindAction:(NSInteger)tag;

- (void)hide;

@property (weak) id<WebFindBarControllerDelegate> delegate;
@property (weak) id<NSTextFinderBarContainer> viewContainer;

@end

@protocol WebFindBarControllerDelegate <NSObject>

- (void)findBarController:(WebFindBarController *)controller searchFor:(NSString *)str;
- (void)findBarControllerScrollToSelection:(WebFindBarController *)controller;
- (void)findBarControllerGoNext:(WebFindBarController *)controller;
- (void)findBarControllerGoPrevious:(WebFindBarController *)controller;

- (void)findBarController:(WebFindBarController *)controller selectedTextForFind:(void (^)(NSString *))handler;

@end

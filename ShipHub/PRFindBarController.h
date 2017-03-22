//
//  PRFindBarController.h
//  ShipHub
//
//  Created by James Howard on 3/21/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol PRFindBarControllerDelegate;

@interface PRFindBarController : NSViewController

- (void)performFindAction:(NSInteger)tag;

- (void)hide;

@property (weak) id<PRFindBarControllerDelegate> delegate;
@property (weak) id<NSTextFinderBarContainer> viewContainer;

@end

@protocol PRFindBarControllerDelegate <NSObject>

- (void)findBarController:(PRFindBarController *)controller searchFor:(NSString *)str;
- (void)findBarControllerScrollToSelection:(PRFindBarController *)controller;
- (void)findBarControllerGoNext:(PRFindBarController *)controller;
- (void)findBarControllerGoPrevious:(PRFindBarController *)controller;

- (void)findBarController:(PRFindBarController *)controller selectedTextForFind:(void (^)(NSString *))handler;

@end

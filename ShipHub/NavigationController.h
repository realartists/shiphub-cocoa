//
//  NavigationController.h
//  Ship
//
//  Created by James Howard on 8/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NavigationController : NSViewController

- (id)initWithRootViewController:(NSViewController *)root;

@property (nonatomic, readonly) NSArray *viewControllers;

@property(nonatomic, readonly) NSViewController *topViewController;

- (void)pushViewController:(NSViewController *)vc animated:(BOOL)animate;
- (void)popViewControllerAnimated:(BOOL)animate;
- (void)popToRootViewControllerAnimated:(BOOL)animate;

@end

@interface NavigationItem : NSObject

@property BOOL hidesBackButton;
@property NSAttributedString *attributedTitle;

@end

@interface NSViewController (NavigationControllerAccess)

@property (nonatomic, readonly) NavigationController *navigationController;
@property (nonatomic, readonly) NavigationItem *navigationItem;

@end

@interface NSViewController (NavigationControllerActions)

- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;

@end

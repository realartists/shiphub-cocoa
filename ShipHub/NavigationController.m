//
//  NavigationController.m
//  Ship
//
//  Created by James Howard on 8/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "NavigationController.h"

#import "Extras.h"

#import <Quartz/Quartz.h>
#import <objc/objc-runtime.h>

@interface NavigationController () {
    BOOL _transitioning;
    NSMutableArray *_transitionQ;
}

@property IBOutlet NSButton *backButton;
@property IBOutlet NSTextField *titleField;
@property IBOutlet NSView *container;

@end

@implementation NavigationController

- (NSString *)nibName {
    return @"NavigationController";
}

- (id)initWithRootViewController:(NSViewController *)root {
    if (self = [super init]) {
        _transitionQ = [NSMutableArray array];
        [self addChildViewController:root];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSViewController *root = [self.childViewControllers firstObject];
    [self childWillAppear:root animated:NO];
    [_container setContentView:root.view];
    [self updateTitleField:root];
    _backButton.alphaValue = 0.0;
    NSMutableAttributedString *str = [_backButton.attributedTitle mutableCopy];
    [str addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, str.length)];
    _backButton.attributedTitle = str;
    [self childDidAppear:root animated:NO];
}

- (void)updateTitleField:(NSViewController *)vc {
    NSString *title = vc.title;
    NSAttributedString *attributedTitle = vc.navigationItem.attributedTitle;
    if (attributedTitle) {
        _titleField.attributedStringValue = attributedTitle;
    } else {
        _titleField.stringValue = title ?: @"";
    }
}

- (NSArray *)viewControllers {
    return self.childViewControllers;
}

- (NSViewController *)topViewController {
    return [self.viewControllers lastObject];
}

static NSTimeInterval duration() {
    NSEvent *current = [NSApp currentEvent];
    NSTimeInterval d = 0.3;
    if ([current modifierFlags] & NSShiftKeyMask) {
        d *= 10.0;
    }
    return d;
}

- (void)pushViewController:(NSViewController *)vc animated:(BOOL)animate {
    if (_transitioning) {
        [_transitionQ addObject:@[@"push", vc, @(animate)]];
        return;
    }
    
    [self beginTransition];
    [self view];
    
    NSViewController *oldVC = [[self childViewControllers] lastObject];
    [self addChildViewController:vc];
    
    NSView *newView = vc.view;
    NSView *oldView = oldVC.view;
    
    [self childWillAppear:vc animated:animate];
    [self childWillDisappear:oldVC animated:animate];

    CGRect oldStartFrame = [oldView frame];
    CGRect newEndFrame = oldStartFrame;
    CGRect newStartFrame = newEndFrame;
    newStartFrame.origin.x += CGRectGetWidth(newStartFrame);
    CGRect oldEndFrame = oldStartFrame;
    oldEndFrame.origin.x -= CGRectGetWidth(oldStartFrame);
    
    newView.frame = newStartFrame;
    [_container addSubview:newView];
    
    NSTimeInterval d = duration();
    
    dispatch_block_t work = ^{
        dispatch_block_t completion = ^{
            [oldView removeFromSuperview];
            [self childDidAppear:vc animated:animate];
            [self childDidDisappear:oldVC animated:animate];
            
            [self endTransition];
        };
        
        if (animate) {
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *outer) {
                [outer setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
                [outer setDuration:animate?d:0.0];
                
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    [context setDuration:animate?d/2.0:0.0];
                    
                    _titleField.animator.alphaValue = 0.0;
                } completionHandler:^{
                    
                    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                        [context setDuration:animate?d/2.0:0.0];
                        
                        [self updateTitleField:vc];
                        
                        _backButton.animator.alphaValue = vc.navigationItem.hidesBackButton ? 0.0 : 1.0;
                        _titleField.animator.alphaValue = 1.0;
                    } completionHandler:nil];
                }];
                
                newView.animator.frame = newEndFrame;
                oldView.animator.frame = oldEndFrame;
                
            } completionHandler:completion];
        } else {
            [self updateTitleField:vc];
            _backButton.alphaValue = vc.navigationItem.hidesBackButton ? 0.0 : 1.0;
            _titleField.alphaValue = 1.0;
            
            newView.frame = newEndFrame;
            oldView.frame = oldEndFrame;
            
            completion();
        }
    };
    
    if (animate) {
        // why the dispatch after?
        // because appkit is a piece of shit and can generate the wrong fromPosition in the animation it adds to newView.layer.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), work);
    } else {
        work();
    }
}

- (void)popViewControllerAnimated:(BOOL)animate {
    NSAssert([self.childViewControllers count] > 1, @"Stack must have more than 1 thing in it");
    
    if (_transitioning) {
        [_transitionQ addObject:@[@"pop", @(animate)]];
        return;
    }
    
    [self beginTransition];
    NSArray *stack = self.childViewControllers;
    BOOL toRoot = stack.count == 2;
    NSViewController *newVC = stack[stack.count-2];
    NSViewController *oldVC = stack[stack.count-1];
    
    NSView *newView = newVC.view;
    NSView *oldView = oldVC.view;
    
    [self childWillAppear:newVC animated:animate];
    [self childWillDisappear:oldVC animated:animate];
    
    CGRect oldStartFrame = [oldView frame];
    CGRect newEndFrame = oldStartFrame;
    CGRect newStartFrame = newEndFrame;
    newStartFrame.origin.x -= CGRectGetWidth(newStartFrame);
    CGRect oldEndFrame = oldStartFrame;
    oldEndFrame.origin.x += CGRectGetWidth(oldStartFrame);
    
    newView.frame = newStartFrame;
    [_container addSubview:newView];
    
    dispatch_block_t completion = ^{
        [oldView removeFromSuperview];
        [self childDidAppear:newVC animated:animate];
        [self childDidDisappear:oldVC animated:animate];
        
        [oldVC removeFromParentViewController];
        
        [self endTransition];
    };
    
    if (animate) {
        NSTimeInterval d = duration();
        
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *outer) {
            [outer setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [outer setDuration:animate?d:0.0];
            
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                [context setDuration:animate?d/2.0:0.0];
                
                _titleField.animator.alphaValue = 0.0;
            } completionHandler:^{
                
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    [context setDuration:animate?d/2.0:0.0];
                    
                    [self updateTitleField:newVC];
                    
                    _backButton.animator.alphaValue = (newVC.navigationItem.hidesBackButton || toRoot) ? 0.0 : 1.0;
                    _titleField.animator.alphaValue = 1.0;
                } completionHandler:nil];
            }];
            
            newView.animator.frame = newEndFrame;
            oldView.animator.frame = oldEndFrame;
            
        } completionHandler:completion];
    } else {
        [self updateTitleField:newVC];
        _backButton.alphaValue = (newVC.navigationItem.hidesBackButton || toRoot) ? 0.0 : 1.0;
        _titleField.alphaValue = 1.0;
        newView.frame = newEndFrame;
        oldView.frame = oldEndFrame;
        
        completion();
    }
}

- (void)popToRootViewControllerAnimated:(BOOL)animate {
    if ([self.childViewControllers count] == 1) {
        return;
    }
    
    if (_transitioning) {
        [_transitionQ addObject:@[@"popAll", @(animate)]];
        return;
    }
    
    [self beginTransition];
    NSArray *stack = self.childViewControllers;
    NSViewController *newVC = stack[0];
    NSViewController *oldVC = stack[stack.count-1];
    
    NSView *newView = newVC.view;
    NSView *oldView = oldVC.view;
    
    [self childWillAppear:newVC animated:animate];
    [self childWillDisappear:oldVC animated:animate];
    
    CGRect oldStartFrame = [oldView frame];
    CGRect newEndFrame = oldStartFrame;
    CGRect newStartFrame = newEndFrame;
    newStartFrame.origin.x -= CGRectGetWidth(newStartFrame);
    CGRect oldEndFrame = oldStartFrame;
    oldEndFrame.origin.x += CGRectGetWidth(oldStartFrame);
    
    newView.frame = newStartFrame;
    [_container addSubview:newView];
    
    dispatch_block_t completion = ^{
        [oldView removeFromSuperview];
        [self childDidAppear:newVC animated:animate];
        [self childDidDisappear:oldVC animated:animate];
        
        NSInteger count = (NSInteger)([stack count]);
        NSArray *removeThese = [stack copy];
        for (NSInteger i = count-1; i > 0; i--) {
            [removeThese[i] removeFromParentViewController];
        }
        
        NSAssert([[_container subviews] count] == 1, @"Should only have 1 subview in container now");
        
        [self endTransition];
    };
    
    if (animate) {
    
        NSTimeInterval d = duration();
        
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *outer) {
            [outer setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [outer setDuration:animate?d:0.0];
            
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                [context setDuration:animate?d/2.0:0.0];
                
                _titleField.animator.alphaValue = 0.0;
            } completionHandler:^{
                
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    [context setDuration:animate?d/2.0:0.0];
                    
                    _backButton.animator.alphaValue = 0.0;
                    [self updateTitleField:newVC];
                    _titleField.animator.alphaValue = 1.0;
                } completionHandler:nil];
            }];
            
            newView.animator.frame = newEndFrame;
            oldView.animator.frame = oldEndFrame;
            
        } completionHandler:completion];
    } else {
        _backButton.alphaValue = 0.0;
        [self updateTitleField:newVC];
        _titleField.alphaValue = 1.0;
        newView.frame = newEndFrame;
        oldView.frame = oldEndFrame;
        
        completion();
    }
}

- (void)beginTransition {
    _transitioning = YES;
}

- (void)endTransition {
    _transitioning = NO;
    
    NSArray *op = [_transitionQ firstObject];
    if (op) {
        [_transitionQ removeObjectAtIndex:0];
        
        NSString *action = op[0];
        if ([action isEqualToString:@"push"]) {
            NSViewController *vc = op[1];
            BOOL animate = [op[2] boolValue];
            [self pushViewController:vc animated:animate];
        } else if ([action isEqualToString:@"pop"]) {
            BOOL animate = [op[1] boolValue];
            [self popViewControllerAnimated:animate];
        } else if ([action isEqualToString:@"popAll"]) {
            BOOL animate = [op[1] boolValue];
            [self popToRootViewControllerAnimated:animate];
        } else {
            NSAssert(NO, @"Unknown action %@", action);
        }
    }
}

- (IBAction)goBack:(id)sender {
    if (!_transitioning && self.childViewControllers.count > 1) {
        [self popViewControllerAnimated:YES];
    }
}

- (void)insertChildViewController:(NSViewController *)childViewController atIndex:(NSInteger)index {
    [super insertChildViewController:childViewController atIndex:index];
    
    [childViewController addObserver:self forKeyPath:@"navigationItem.hidesBackButton" options:0 context:NULL];
}

- (void)removeChildViewControllerAtIndex:(NSInteger)index {
    NSViewController *child = [self childViewControllers][index];
    [child removeObserver:self forKeyPath:@"navigationItem.hidesBackButton" context:NULL];
    [super removeChildViewControllerAtIndex:index];
}

- (void)dealloc {
    for (NSViewController *child in [self childViewControllers]) {
        [child removeObserver:self forKeyPath:@"navigationItem.hidesBackButton" context:NULL];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (_transitioning) {
        return;
    }
    
    if ([keyPath isEqualToString:@"navigationItem.hidesBackButton"]) {
        NSViewController *vc = object;
        if ([[self childViewControllers] lastObject] == vc) {
            BOOL hide = vc.navigationItem.hidesBackButton;
            [NSAnimationContext runAnimationGroup:^(NSAnimationContext *anim) {
                [anim setDuration:duration()/2.0];
                _backButton.alphaValue = hide ? 0.0 : 1.0;
            } completionHandler:nil];
        }
    }
}

- (void)childWillAppear:(NSViewController *)child animated:(BOOL)animated {
    if ([child respondsToSelector:@selector(viewWillAppear:)]) {
        [child viewWillAppear:animated];
    }
}

- (void)childWillDisappear:(NSViewController *)child animated:(BOOL)animated {
    if ([child respondsToSelector:@selector(viewWillDisappear:)]) {
        [child viewWillDisappear:animated];
    }
}

- (void)childDidAppear:(NSViewController *)child animated:(BOOL)animated {
    if ([child respondsToSelector:@selector(viewDidAppear:)]) {
        [child viewDidAppear:animated];
    }
}

- (void)childDidDisappear:(NSViewController *)child animated:(BOOL)animated {
    if ([child respondsToSelector:@selector(viewDidDisappear:)]) {
        [child viewDidDisappear:animated];
    }
}

@end

@implementation NSViewController (NavigationControllerAccess)

- (NavigationController *)navigationController {
    NSViewController *vc = self;
    NSViewController *parent = nil;
    do {
        parent = [vc parentViewController];
        if ([parent isKindOfClass:[NavigationController class]]) {
            return (NavigationController *)parent;
        } else {
            vc = parent;
        }
    } while (parent);
    return nil;
}

- (NavigationItem *)navigationItem {
    NavigationItem *item = objc_getAssociatedObject(self, "NavigationItem");
    if (!item) {
        item = [NavigationItem new];
        objc_setAssociatedObject(self, "NavigationItem", item, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return item;
}

@end

@implementation NavigationItem
@end

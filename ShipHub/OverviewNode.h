//
//  OverviewNode.h
//  Ship
//
//  Created by James Howard on 6/3/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NSPredicate *(^OverviewPredicateBuilder)();
typedef void (^OverviewNodeDropHandler)(NSArray<NSString *> *issueIdentifiers);
@class OverviewKnob;

@interface OverviewNode : NSObject

@property NSString *title;
@property (nonatomic, strong) NSViewController *viewController;
@property (nonatomic, strong) NSPredicate *predicate;
@property (copy) OverviewPredicateBuilder predicateBuilder;

@property id representedObject;

@property NSMutableArray *children;
@property NSMutableArray *knobs;

- (void)addChild:(OverviewNode *)node;
- (void)addKnob:(OverviewKnob *)knob;

- (void)removeLastChild;
- (void)removeChild:(OverviewNode *)node;
- (void)insertChild:(OverviewNode *)node atIndex:(NSUInteger)idx;

@property (weak) id target;
@property SEL action;

@property (weak) OverviewNode *parent;

@property (nonatomic, strong) NSString *identifier;

@property NSMenu *menu;
@property (getter=isTitleEditable) BOOL titleEditable;

@property NSUInteger count;
@property NSArray *sparkValues;
@property BOOL showCount;
@property BOOL countOpenOnly;
@property BOOL allowChart;

@property BOOL showProgress;
@property double progress;

@property (nonatomic, strong) NSString *path;

@property (nonatomic, strong) NSString *toolTip;

@property (strong) NSImage *icon;

@property (copy) OverviewNodeDropHandler dropHandler;

@end

@interface OverviewKnob : NSViewController

- (id)initWithDefaultsIdentifier:(NSString *)identifier;
+ (instancetype)knobWithDefaultsIdentifier:(NSString *)identifier;

@property (weak) id target;
@property SEL action;

@property (readonly) NSString *defaultsIdentifier;

- (IBAction)moveBackward:(id)sender;
- (IBAction)moveForward:(id)sender;

@end

@interface DateKnob : OverviewKnob

@property (readonly) NSInteger daysAgo;

@end

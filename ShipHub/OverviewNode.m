//
//  OverviewNode.m
//  Ship
//
//  Created by James Howard on 6/3/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "OverviewNode.h"
#import "Extras.h"
#import "Defaults.h"

@implementation OverviewNode

- (id)init {
    if (self = [super init]) {
        _count = NSNotFound;
        _progress = -1.0;
        _allowChart = YES;
    }
    return self;
}

- (void)insertChild:(OverviewNode *)node atIndex:(NSUInteger)idx {
    if (!_children) {
        _children = [NSMutableArray array];
    }
    [_children insertObject:node atIndex:idx];
    node.parent = self;
}

- (void)addChild:(OverviewNode *)node {
    if (!_children) {
        _children = [NSMutableArray array];
    }
    [_children addObject:node];
    node.parent = self;
}

- (void)removeLastChild {
    OverviewNode *node = [_children lastObject];
    node.parent = nil;
    [_children removeLastObject];
}

- (void)removeChild:(OverviewNode *)node {
    node.parent = nil;
    [_children removeObject:node];
}

- (void)addKnob:(OverviewKnob *)knob {
    if (!_knobs) {
        _knobs = [NSMutableArray array];
    }
    [_knobs addObject:knob];
    knob.target = self;
    knob.action = @selector(knobUpdated:);
}

- (NSPredicate *)predicate {
    if (_predicate) return _predicate;
    if (_predicateBuilder) {
        return _predicateBuilder();
    }
    return nil;
}

- (NSString *)identifier {
    if (!_identifier) {
        NSMutableString *identifier = [NSMutableString stringWithString:self.title ?: @""];
        OverviewNode *parent = self.parent;
        if (parent) {
            [identifier insertString:@"." atIndex:0];
            [identifier insertString:[parent identifier] atIndex:0];
        }
        return identifier;
    }
    return _identifier;
}

- (void)knobUpdated:(id)sender {
    [self sendAction:self.action toTarget:self.target];
}

- (NSString *)path {
    if (!_path) {
        return self.title;
    }
    return _path;
}

@synthesize title = _title;

- (void)setTitle:(NSString *)title {
    NSParameterAssert(title);
    _title = title;
}

- (NSString *)title {
    return _title;
}

@end

@implementation OverviewKnob

- (id)initWithDefaultsIdentifier:(NSString *)identifier {
    if (self = [super init]) {
        _defaultsIdentifier = [identifier copy];
    }
    return self;
}

+ (instancetype)knobWithDefaultsIdentifier:(NSString *)identifier {
    return [[[self class] alloc] initWithDefaultsIdentifier:identifier];
}

- (void)reset { }

- (IBAction)moveBackward:(id)sender { }
- (IBAction)moveForward:(id)sender { }

@end

@interface DateKnob ()

@property (strong) IBOutlet NSSlider *slider;
@property (strong) IBOutlet NSBox *box;

@end

@implementation DateKnob

- (NSString *)nibName { return @"DateKnob"; }

- (id)initWithDefaultsIdentifier:(NSString *)identifier {
    if (self = [super initWithDefaultsIdentifier:identifier]) {
        _daysAgo = 7;
        if (self.defaultsIdentifier) {
            _daysAgo = [[NSUserDefaults standardUserDefaults] integerForKey:[self daysAgoDefaultsKey] fallback:_daysAgo];
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _slider.integerValue = daysToValue(_daysAgo);
    [self update];
}

- (NSString *)daysAgoDefaultsKey {
    return [NSString stringWithFormat:@"%@.daysAgo", self.defaultsIdentifier];
}

static NSInteger valueToDays(NSInteger value) {
    switch (value) {
        case 4: return 1;
        case 3: return 7;
        case 2: return 30;
        case 1: return 90;
        case 0: return 365;
        default: return 1;
    }
}

static NSInteger daysToValue(NSInteger days) {
    switch (days) {
        case 1: return 4;
        case 7: return 3;
        case 30: return 2;
        case 90: return 1;
        case 365: return 0;
        default: return 4;
    }
}

static NSString *valueToString(NSInteger value) {
    switch (value) {
        case 3: return NSLocalizedString(@"Within the last week", nil);
        case 2: return NSLocalizedString(@"Within the last month", nil);
        case 1: return NSLocalizedString(@"Within the last 3 months", nil);
        case 0: return NSLocalizedString(@"Within the last year", nil);
        case 4:
        default: return NSLocalizedString(@"Within the last day", nil);
    }
}

- (void)update {
    _box.title = valueToString(daysToValue(_daysAgo));
}

- (IBAction)sliderChanged:(id)sender {
    _daysAgo = valueToDays(_slider.integerValue);
    [[NSUserDefaults standardUserDefaults] setInteger:_daysAgo forKey:[self daysAgoDefaultsKey]];
    [self update];
    [self sendAction:self.action toTarget:self.target];
}

- (IBAction)moveBackward:(id)sender {
    if (_slider.integerValue > _slider.minValue) {
        _slider.integerValue--;
        [self sliderChanged:sender];
    }
}

- (IBAction)moveForward:(id)sender {
    if (_slider.integerValue < _slider.maxValue) {
        _slider.integerValue++;
        [self sliderChanged:sender];
    }
}

@end

//
//  LabelRowTemplate.m
//  ShipHub
//
//  Created by James Howard on 7/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "LabelRowTemplate.h"

#import "Extras.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Label.h"
#import "Repo.h"

@interface LabelPopUp : NSPopUpButton

@end

@implementation LabelPopUp

- (void)showMenu {
    if (self.enabled) {
        self.menu.minimumWidth = self.bounds.size.width;
        self.menu.font = self.font;
        NSMenuItem *selected = nil;
        NSInteger idx = [self indexOfSelectedItem];
        
        if (idx != NSNotFound) {
            selected = [self.menu itemAtIndex:idx];
        }
        
        [self.menu popUpMenuPositioningItem:selected atLocation:CGPointMake(0, self.bounds.size.height + 3.0) inView:self];
    }
}

- (void)performClick:(id)sender {
    [self showMenu];
}

- (void)mouseDown:(NSEvent *)theEvent {
    [self showMenu];
}

@end

@interface LabelRowTemplate ()

@property (nonatomic, strong) NSPopUpButton *popUp;

@end

@implementation LabelRowTemplate

- (id)init {
    self = [super initWithLeftExpressions:@[[NSExpression expressionForKeyPath:@"labels.name"]] rightExpressionAttributeType:NSStringAttributeType modifier:NSAnyPredicateModifier operators:@[@(NSEqualToPredicateOperatorType)] options:0];
    return self;
}

- (NSPopUpButton *)popUp {
    if (!_popUp) {
        _popUp = [[LabelPopUp alloc] initWithFrame:CGRectMake(0, 0, 160.0, 17.0)];
        [_popUp setBezelStyle:NSRoundRectBezelStyle];
        [_popUp setControlSize:NSSmallControlSize];
        [_popUp setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
        NSMenu *menu = [NSMenu new];
        
        MetadataStore *meta = [[DataStore activeStore] metadataStore];
        
        NSMutableDictionary *labelColors = [NSMutableDictionary new];
        
        NSMutableSet *allLabels = [NSMutableSet new];
        for (Repo *r in [meta activeRepos]) {
            for (Label *label in [meta labelsForRepo:r]) {
                [allLabels addObject:label.name];
                labelColors[label.name] = label.color;
            }
        }
        
        NSMenuItem *m;
        NSArray *labels = [[allLabels allObjects] sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
        
        for (NSString *label in labels) {
            m = [menu addItemWithTitle:label action:nil keyEquivalent:@""];
            m.target = self;
            m.representedObject = label;
            
            NSImage *swatch = [[NSImage alloc] initWithSize:CGSizeMake(12.0, 12.0)];
            [swatch lockFocus];
            
            NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:CGRectMake(1.0, 1.0, 10.0, 10.0) xRadius:2.0 yRadius:2.0];
            
            path.lineWidth = [[NSScreen mainScreen] backingScaleFactor] > 1.0 ? 0.5 : 1.0;
            
            [[NSColor darkGrayColor] setStroke];
            [labelColors[label] setFill];
            
            [path fill];
            [path stroke];
            
            [swatch unlockFocus];
            
            m.image = swatch;
        }
        
        _popUp.menu = menu;
    }
    return _popUp;
}

- (NSArray *)templateViews {
    NSMutableArray *a = [[super templateViews] mutableCopy];
    [a removeLastObject];
    [a addObject:[self popUp]];
    return a;
}

- (void)setPredicate:(NSPredicate *)predicate {
    NSComparisonPredicate *c0 = (id)predicate;
    NSExpression *rhs = c0.rightExpression;
    NSString *labelName = [rhs expressionValueWithObject:nil context:NULL]?:@"";
    
    NSInteger idx = [[self popUp] indexOfItemWithTitle:labelName];
    if (idx == -1) {
        [[self popUp] addItemWithTitle:labelName];
        [[self popUp] selectItemWithTitle:labelName];
    } else {
        [[self popUp] selectItemAtIndex:idx];
    }
    
    [super setPredicate:predicate];
}

- (NSPredicate *)predicateWithSubpredicates:(NSArray *)subpredicates {
    NSMenu *menu = [[self popUp] menu];
    NSInteger idx = [[self popUp] indexOfSelectedItem];
    
    NSString *item = [[menu itemAtIndex:idx] representedObject];
    
    return [NSPredicate predicateWithFormat:@"ANY labels.name = %@", item];
}

@end

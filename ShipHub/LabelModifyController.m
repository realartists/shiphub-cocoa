//
//  LabelModifyController.m
//  ShipHub
//
//  Created by James Howard on 7/27/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "LabelModifyController.h"

#import "Extras.h"
#import "Error.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Issue.h"
#import "Label.h"
#import "Repo.h"

@interface LabelModifyButton : NSButton
@end

@interface LabelModifyButtonCell : NSButtonCell
@end

@interface LabelModifyCell : NSTableCellView

@property IBOutlet NSButton *stateButton;
@property IBOutlet NSImageView *swatch;

@end

@interface LabelModifyController () <NSTableViewDataSource, NSTableViewDelegate>

@property IBOutlet NSTableView *table;
@property IBOutlet NSButton *okButton;

@property NSMutableArray<Label *> *labels;
@property NSMutableArray<NSNumber *> *labelStates;

@end

@implementation LabelModifyController

- (id)initWithIssues:(NSArray<Issue *> *)issues {
    if (self = [super initWithIssues:issues]) {
        DataStore *store = [DataStore activeStore];
        MetadataStore *meta = [store metadataStore];
        
        NSMutableArray *labels = [NSMutableArray new];
        NSMutableSet *unionLabels = [NSMutableSet new];
        NSMutableSet *repos = [NSMutableSet new];
        NSMutableSet *usedLabels = [NSMutableSet new];
        
        for (Issue *i in issues) {
            Repo *r = [i repository];
            
            [usedLabels addObjectsFromArray:[i.labels arrayByMappingObjects:^id(Label *obj) {
                return [obj name];
            }]];
            
            if (![repos containsObject:r]) {
                [repos addObject:r];
                NSArray *options = [meta labelsForRepo:r];
                
                for (Label *l in options) {
                    if (![unionLabels containsObject:l.name]) {
                        [unionLabels addObject:l.name];
                        [labels addObject:l];
                    }
                }
            }
        }
        
        [labels sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        
        _labelStates = [NSMutableArray new];
        for (Label *label in labels) {
            if ([usedLabels containsObject:label.name]) {
                [_labelStates addObject:@(NSMixedState)];
            } else {
                [_labelStates addObject:@(NSOffState)];
            }
        }
        _labels = labels;
    }
    return self;
}

- (NSString *)nibName { return @"LabelModifyController"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    _okButton.enabled = NO;
}

- (void)stateDidChange:(id)sender {
    NSButton *button = sender;
    NSInteger row = [button.extras_representedObject integerValue];
    _labelStates[row] = @(button.state);
    _okButton.enabled = YES;
}

- (IBAction)submit:(id)sender {
    [self.delegate bulkModifyDidBegin:self];
    
    DataStore *store = [DataStore activeStore];
    MetadataStore *meta = [store metadataStore];
    
    NSMutableArray *errors = [NSMutableArray new];
    dispatch_group_t group = dispatch_group_create();

    for (Issue *issue in self.issues) {
        NSMutableSet *issueLabels = [NSMutableSet setWithArray:[issue.labels arrayByMappingObjects:^id(id obj) {
            return [obj name];
        }]];
        
        NSSet *availableLabels = [NSSet setWithArray:[[meta labelsForRepo:issue.repository] arrayByMappingObjects:^id(id obj) {
            return [obj name];
        }]];
        
        BOOL hasChanges = NO;
        for (NSInteger i = 0; i < _labels.count; i++) {
            NSString *name = _labels[i].name;
            
            NSInteger state = [_labelStates[i] integerValue];
            
            if (state == NSOnState) {
                if ([availableLabels containsObject:name]
                    && ![issueLabels containsObject:name])
                {
                    [issueLabels addObject:name];
                    hasChanges = YES;
                }
            } else if (state == NSOffState) {
                if ([issueLabels containsObject:name]) {
                    [issueLabels removeObject:name];
                    hasChanges = YES;
                }
            }
        }
        
        if (hasChanges) {
            dispatch_group_enter(group);
            [store patchIssue:@{@"labels" : [issueLabels allObjects]} issueIdentifier:issue.fullIdentifier completion:^(Issue *i, NSError *e) {
                if (e) {
                    [errors addObject:e];
                }
                dispatch_group_leave(group);
            }];
        }
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [self.delegate bulkModifyDidEnd:self error:[errors firstObject]];
    });
}

- (IBAction)cancel:(id)sender {
    [self.delegate bulkModifyDidCancel:self];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _labels.count;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    return _labels[row];
}

#pragma mark - NSTableViewDelegate

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    Label *label = _labels[row];
    LabelModifyCell *cell = [tableView makeViewWithIdentifier:@"Label" owner:self];
    
    NSInteger state = [_labelStates[row] integerValue];
    cell.stateButton.extras_representedObject = @(row);
    cell.stateButton.state = state;
    cell.stateButton.target = self;
    cell.stateButton.action = @selector(stateDidChange:);
    
    NSImage *swatch = [[NSImage alloc] initWithSize:CGSizeMake(14.0, 14.0)];
    [swatch lockFocus];
    
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:CGRectMake(1.0, 1.0, 12.0, 12.0) xRadius:6.0 yRadius:6.0];
    
    path.lineWidth = [[NSScreen mainScreen] backingScaleFactor] > 1.0 ? 0.5 : 1.0;
    
    [[NSColor darkGrayColor] setStroke];
    [label.color setFill];
    
    [path fill];
    [path stroke];
    
    [swatch unlockFocus];
    
    cell.swatch.image = swatch;
    cell.stateButton.title = [NSString stringWithFormat:@"      %@", label.name];

    CGSize size = [cell.stateButton intrinsicContentSize];
    CGRect f = cell.stateButton.frame;
    f.size.width = size.width + 3.0;
    
    cell.stateButton.frame = f;
    
    return cell;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    LabelModifyCell *cell = [tableView viewAtColumn:0 row:row makeIfNecessary:NO];
    NSButton *button = cell.stateButton;
    [button setNextState];
    _labelStates[row] = @(button.state);
    _okButton.enabled = YES;
    
    return NO;
}

@end

@implementation LabelModifyCell

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize { }
- (void)resizeWithOldSuperviewSize:(NSSize)oldSize { }

@end

@implementation LabelModifyButton
// https://mikeash.com/pyblog/custom-nscells-done-right.html
- (id)initWithCoder:(NSCoder *)aCoder {
    NSKeyedUnarchiver *coder = (id)aCoder;
    
    // gather info about the superclass's cell and save the archiver's old mapping
    Class superCell = [[self superclass] cellClass];
    NSString *oldClassName = NSStringFromClass( superCell );
    Class oldClass = [coder classForClassName: oldClassName];
    if( !oldClass )
        oldClass = superCell;
    
    // override what comes out of the unarchiver
    [coder setClass: [[self class] cellClass] forClassName: oldClassName];
    
    // unarchive
    self = [super initWithCoder: coder];
    
    // set it back
    [coder setClass: oldClass forClassName: oldClassName];
    
    return self;
}

+ (Class)cellClass {
    return [LabelModifyButtonCell class];
}
@end

@implementation LabelModifyButtonCell
- (NSInteger)nextState {
    NSInteger state = self.state;
    if (state == NSMixedState || state == NSOnState) {
        state = NSOffState;
    } else {
        state = NSOnState;
    }
    return state;
}
@end

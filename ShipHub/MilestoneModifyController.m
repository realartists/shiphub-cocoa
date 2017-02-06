//
//  MilestoneModifyController.m
//  ShipHub
//
//  Created by James Howard on 7/27/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "MilestoneModifyController.h"

#import "Extras.h"
#import "Error.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Issue.h"
#import "Milestone.h"
#import "Repo.h"
#import "Account.h"

@interface MilestoneCell : NSTableCellView

@property IBOutlet NSTextField *usedView;

@end

@interface MilestoneModifyController () <NSTableViewDataSource, NSTableViewDelegate>

@property IBOutlet NSTableView *table;
@property IBOutlet NSButton *okButton;

@property NSArray *unionMilestones;
@property NSSet *intersectionMilestones;
@property NSSet *usedMilestones;

@end

@implementation MilestoneModifyController

- (id)initWithIssues:(NSArray<Issue *> *)issues {
    if (self = [super initWithIssues:issues]) {
        DataStore *store = [DataStore activeStore];
        MetadataStore *meta = [store metadataStore];
        
        NSMutableSet *unionMilestones = [NSMutableSet new];
        NSMutableSet *usedMilestones = [NSMutableSet new];
        NSMutableSet *repos = [NSMutableSet new];
        
        for (Issue *i in issues) {
            Repo *r = [i repository];
            
            if (i.milestone) {
                [usedMilestones addObject:i.milestone.title];
            } else {
                [usedMilestones addObject:[NSNull null]];
            }
            
            if (![repos containsObject:r]) {
                NSArray<Milestone *> *ms = [meta activeMilestonesForRepo:r];
                [unionMilestones addObjectsFromArray:[ms arrayByMappingObjects:^id(Milestone *obj) {
                    return [obj title];
                }]];
                [repos addObject:r];
            }
        }
        
        NSMutableSet *intersectionMilestones = [unionMilestones mutableCopy];
        for (Repo *r in repos) {
            NSArray<Milestone *> *ms = [meta activeMilestonesForRepo:r];
            NSArray<NSString *> *titles = [ms arrayByMappingObjects:^id(Milestone *obj) {
                return [obj title];
            }];
            [intersectionMilestones intersectSet:[NSSet setWithArray:titles]];
        }
        
        NSMutableArray *unionList = [NSMutableArray arrayWithArray:[unionMilestones allObjects]];
        [unionList sortUsingSelector:@selector(localizedStandardCompare:)];
        [unionList insertObject:[NSNull null] atIndex:0];
        [intersectionMilestones addObject:[NSNull null]];
        
        _unionMilestones = unionList;
        _intersectionMilestones = intersectionMilestones;
        _usedMilestones = usedMilestones;
    }
    return self;
}

- (NSString *)nibName { return @"MilestoneModifyController"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    _okButton.enabled = NO;
}

- (IBAction)submit:(id)sender {
    [self.delegate bulkModifyDidBegin:self];
    
    id milestone = _unionMilestones[[_table selectedRow]];
    NSString *milestoneTitle = [milestone isKindOfClass:[NSString class]] ? milestone : nil;
    
    DataStore *store = [DataStore activeStore];
    MetadataStore *meta = [store metadataStore];
    
    NSMutableArray *errors = [NSMutableArray new];
    dispatch_group_t group = dispatch_group_create();
    
    for (Issue *issue in self.issues) {
        NSString *issueMilestoneTitle = issue.milestone.title;
        
        BOOL needsChange =
            (issueMilestoneTitle == nil && milestoneTitle != nil)
            || (milestoneTitle == nil && issueMilestoneTitle != nil)
            || ![issueMilestoneTitle isEqualToString:milestoneTitle];
        
        if (needsChange)
        {
            Milestone *next = milestoneTitle ? [meta milestoneWithTitle:milestoneTitle inRepo:issue.repository] : nil;
            dispatch_group_enter(group);
            [store patchIssue:@{ @"milestone" : next?next.number:[NSNull null] } issueIdentifier:issue.fullIdentifier completion:^(Issue *i, NSError *e) {
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
    return _unionMilestones.count;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    return _unionMilestones[row];
}

#pragma mark - NSTableViewDelegate

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    id obj = _unionMilestones[row];
    BOOL available = [_intersectionMilestones containsObject:obj];
    BOOL inUse = [_usedMilestones containsObject:obj];
    
    MilestoneCell *cell = [tableView makeViewWithIdentifier:@"Milestone" owner:self];
    
    if (obj == [NSNull null]) {
        cell.textField.stringValue = NSLocalizedString(@"No Milestone", nil);
    } else {
        NSString *milestone = obj;
        cell.textField.stringValue = milestone;
    }
    
    cell.usedView.hidden = !inUse;
    
    cell.textField.textColor = available ? [NSColor blackColor] : [NSColor lightGrayColor];
    cell.usedView.textColor = cell.textField.textColor;
    
    return cell;
}

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    return [_intersectionMilestones containsObject:_unionMilestones[row]];
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSIndexSet *set = [_table selectedRowIndexes];
    _okButton.enabled = set.count == 1;
}

@end

@implementation MilestoneCell
@end

//
//  AssigneeModifyController.m
//  ShipHub
//
//  Created by James Howard on 7/27/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "AssigneeModifyController.h"

#import "Extras.h"
#import "Error.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Issue.h"
#import "Repo.h"
#import "Account.h"

@interface AssigneeModifyController () <NSTableViewDataSource, NSTableViewDelegate>

@property IBOutlet NSTableView *table;
@property IBOutlet NSButton *okButton;

@property NSArray<Account *> *assignees;

@end

@implementation AssigneeModifyController

- (id)initWithIssues:(NSArray<Issue *> *)issues {
    if (self = [super initWithIssues:issues]) {
        DataStore *store = [DataStore activeStore];
        MetadataStore *meta = [store metadataStore];
        
        NSMutableSet *unionAssignees = [NSMutableSet new];
        
        for (Issue *i in issues) {
            Repo *r = [i repository];
            
            [unionAssignees addObjectsFromArray:[meta assigneesForRepo:r]];
        }
        
        NSMutableArray *unionList = [NSMutableArray arrayWithArray:[unionAssignees allObjects]];
        [unionList sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"login" ascending:YES selector:@selector(localizedStandardCompare:)]]];
        
        _assignees = unionList;
    }
    return self;
}

- (NSString *)nibName { return @"AssigneeModifyController"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    _okButton.enabled = NO;
    
    NSMutableIndexSet *selectMe = [NSMutableIndexSet new];
    for (Issue *i in self.issues) {
        NSSet *assignees = [NSSet setWithArray:[i.assignees arrayByMappingObjects:^id(id obj) {
            return [obj login];
        }]];
        NSIndexSet *idxs = [_assignees indexesOfObjectsPassingTest:^BOOL(Account * _Nonnull obj, NSUInteger k, BOOL * _Nonnull stop) {
            return [assignees containsObject:[obj login]];
        }];
        [selectMe addIndexes:idxs];
    }
    
    [_table selectRowIndexes:selectMe byExtendingSelection:NO];
}

- (IBAction)submit:(id)sender {
    [self.delegate bulkModifyDidBegin:self];
    
    NSIndexSet *selected = [_table selectedRowIndexes];
    NSArray *assigneeLogins = [[_assignees objectsAtIndexes:selected] arrayByMappingObjects:^id(id obj) {
        return [obj login];
    }];
    
    DataStore *store = [DataStore activeStore];
    MetadataStore *meta = [store metadataStore];
    
    NSMutableArray *errors = [NSMutableArray new];
    dispatch_group_t group = dispatch_group_create();
    
    for (Issue *issue in self.issues) {
        NSArray *existing = [issue.assignees arrayByMappingObjects:^id(id obj) {
            return [obj login];
        }];
        
        NSSet *allowed = [NSSet setWithArray:[[meta assigneesForRepo:issue.repository] arrayByMappingObjects:^id(id obj) { return [obj login]; }]];
        
        NSMutableArray *proposed = [assigneeLogins mutableCopy];
        [proposed filterUsingPredicate:[NSPredicate predicateWithFormat:@"SELF IN %@", allowed]];
        
        BOOL needsChange = ![proposed isEqual:existing];
        
        if (needsChange)
        {
            dispatch_group_enter(group);
            [store patchIssue:@{ @"assignees" : proposed } issueIdentifier:issue.fullIdentifier completion:^(Issue *i, NSError *e) {
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
    return _assignees.count;
}

- (nullable id)tableView:(NSTableView *)tableView objectValueForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    return _assignees[row];
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"Assignee" owner:nil];

    cell.textField.stringValue = [_assignees[row] login];
    
    return cell;
}

#pragma mark - NSTableViewDelegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    _okButton.enabled = YES;
}

@end

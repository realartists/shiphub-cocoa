//
//  EditMilestoneController.m
//  Ship
//
//  Created by James Howard on 10/9/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "EditMilestoneController.h"

#import "Extras.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Repo.h"
#import "Account.h"
#import "ProgressSheet.h"
#import "SemiMixedButton.h"

@interface EditMilestoneRepoCell : NSTableCellView

@property IBOutlet SemiMixedButton *checkbox;

@end

@interface EditMilestoneDatePicker : NSDatePicker
@end

@interface EditMilestoneController () <NSOutlineViewDelegate, NSOutlineViewDataSource>

@property IBOutlet NSTextField *nameField;
@property IBOutlet NSTextField *nameInUseLabel;
@property IBOutlet NSPopUpButton *statePopup;
@property IBOutlet NSTextView *descriptionText;
@property IBOutlet NSButton *dueButton;
@property IBOutlet NSDatePicker *duePicker;
@property IBOutlet NSOutlineView *repoOutline;
@property IBOutlet NSButton *updateButton;

@property NSArray<Milestone *> *milestones;
@property NSArray<Account *> *repoOwners;
@property NSDictionary<NSNumber *, NSArray<Repo *> *> *repos;

@property NSMutableSet<NSNumber *> *chosenRepoIdentifiers;
@property NSSet<NSNumber *> *requiredRepoIdentifiers;

@property (copy) void (^completion)(NSArray<Milestone *> *, NSError *error);

@end

@implementation EditMilestoneController

- (id)initWithMilestones:(NSArray<Milestone *> *)miles {
    if (self = [super init]) {
        _milestones = miles;
        
        MetadataStore *ms = [[DataStore activeStore] metadataStore];
        
        _chosenRepoIdentifiers = [NSMutableSet setWithArray:[miles arrayByMappingObjects:^id(Milestone *mile) {
            return [[ms repoWithFullName:mile.repoFullName] identifier];
        }]];
        
        NSMutableDictionary *repos = [NSMutableDictionary new];
        NSMutableArray *repoOwners = [NSMutableArray new];
        for (Account *repoOwner in [ms repoOwners]) {
            NSMutableArray *accountRepos = [[ms reposForOwner:repoOwner] mutableCopy];
            [accountRepos filterUsingPredicate:[NSPredicate predicateWithFormat:@"identifier IN %@", _chosenRepoIdentifiers]];
            [accountRepos sortUsingComparator:^NSComparisonResult(Repo *obj1, Repo *obj2) {
                return [obj1.name localizedStandardCompare:obj2.name];
            }];
            if (accountRepos.count > 0) {
                [repoOwners addObject:repoOwner];
                repos[repoOwner.identifier] = accountRepos;
            }
        }
        
        [repoOwners sortUsingComparator:^NSComparisonResult(Account *obj1, Account *obj2) {
            return [obj1.login localizedStandardCompare:obj2.login];
        }];
        
        if (miles.count == 1) {
            _requiredRepoIdentifiers = [NSSet setWithSet:_chosenRepoIdentifiers];
        }
        
        _repoOwners = repoOwners;
        _repos = repos;
    }
    return self;
}

- (NSString *)windowNibName { return @"EditMilestoneController"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    
    NSDate *dueOn = [[_milestones firstObject] dueOn];
    if (dueOn) {
        _dueButton.state = NSOnState;
        _duePicker.enabled = YES;
        _duePicker.dateValue = dueOn;
    } else {
        _dueButton.state = NSOffState;
        _duePicker.enabled = NO;
        _duePicker.dateValue = [[NSDate date] _ship_dateByAddingDays:@7];
    }
    
    [_statePopup selectItemWithTag:[[_milestones firstObject] isClosed] ? 0 : 1];
    
    _nameField.stringValue = [[_milestones firstObject] title];
    _descriptionText.string = [[_milestones firstObject] milestoneDescription] ?: @"";
    
    [self validateUI];
    
    [_repoOutline expandItem:nil expandChildren:YES];
}

- (void)validateUI {
    NSString *proposedTitle = [_nameField.stringValue trim];
    
    NSDictionary *milestonesByRepo = [NSDictionary lookupWithObjects:_milestones keyPath:@"repoFullName"];
    
    // check if we already have a milestone with that name that isn't our milestone
    BOOL dupeName = NO;
    MetadataStore *ms = [[DataStore activeStore] metadataStore];
    for (NSNumber *repoID in _chosenRepoIdentifiers) {
        Repo *r = [ms repoWithIdentifier:repoID];
        Milestone *existing = [ms milestoneWithTitle:proposedTitle inRepo:r];
        Milestone *myExisting = milestonesByRepo[r.fullName];
        if (existing && ![existing.identifier isEqual:myExisting.identifier]) {
            dupeName = YES;
            break;
        }
    }
    
    _nameInUseLabel.hidden = !dupeName;
    
    _updateButton.enabled = !dupeName && [[_nameField.stringValue trim] length] > 0 && [_chosenRepoIdentifiers count] > 0;
}

- (void)controlTextDidChange:(NSNotification *)obj {
    [self validateUI];
}

- (IBAction)checkboxDidChange:(NSButton *)sender {
    // handle owner selection and repo selection
    id item = [sender extras_representedObject];
    NSInteger state = [sender state];
    
    if ([item isKindOfClass:[Account class]]) {
        NSMutableSet *repoIdentifiers = [[self repoIdentifiersForOwner:item] mutableCopy];
        if (_requiredRepoIdentifiers) {
            [repoIdentifiers minusSet:_requiredRepoIdentifiers];
        }
        if (state == NSOnState) {
            [_chosenRepoIdentifiers unionSet:repoIdentifiers];
        } else if (state == NSOffState) {
            [_chosenRepoIdentifiers minusSet:repoIdentifiers];
        }
    } else {
        Repo *repo = item;
        if (state == NSOnState) {
            [_chosenRepoIdentifiers addObject:repo.identifier];
        } else {
            [_chosenRepoIdentifiers removeObject:repo.identifier];
        }
    }
    
    [_repoOutline reloadData];
    
    [self validateUI];
}

- (NSSet<NSNumber *> *)repoIdentifiersForOwner:(Account *)owner {
    NSArray *repos = _repos[owner.identifier];
    NSSet *repoIdentifierSet = [NSSet setWithArray:[repos arrayByMappingObjects:^id(id obj) {
        return [obj identifier];
    }]];
    return repoIdentifierSet;
}

- (IBAction)dueButtonDidChange:(id)sender {
    _duePicker.enabled = _dueButton.state == NSOnState;
}

- (IBAction)updateMilestone:(id)sender {
    NSWindow *sheetParent = self.window.sheetParent;
    [sheetParent endSheet:self.window];
    
    ProgressSheet *progressSheet = [ProgressSheet new];
    NSString *msg = nil;
    if (_chosenRepoIdentifiers.count == 1) {
        msg = NSLocalizedString(@"Updating Milestone", nil);
    } else {
        msg = NSLocalizedString(@"Updating Milestones", nil);
    }
    progressSheet.message = msg;
    [progressSheet beginSheetInWindow:sheetParent];
    
    MetadataStore *ms = [[DataStore activeStore] metadataStore];
    NSArray *repos = [[_chosenRepoIdentifiers allObjects] arrayByMappingObjects:^id(id obj) {
        return [ms repoWithIdentifier:obj];
    }];
    NSArray *repoFullNames = [repos arrayByMappingObjects:^id(Repo *obj) {
        return [obj fullName];
    }];
    
    NSMutableDictionary *milestoneInfo = [NSMutableDictionary new];
    milestoneInfo[@"title"] = [_nameField.stringValue trim];
    milestoneInfo[@"milestoneDescription"] = [_descriptionText.string trim];
    if (_dueButton.state == NSOnState) {
        milestoneInfo[@"dueOn"] = _duePicker.dateValue;
    } else {
        milestoneInfo[@"dueOn"] = [NSNull null];
    }
    milestoneInfo[@"state"] = [_statePopup selectedTag] == 1 ? @"open" : @"closed";
    
    NSArray *milestones = [_milestones filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"repoFullName IN %@", repoFullNames]];
    
    [[DataStore activeStore] editMilestones:milestones info:milestoneInfo completion:^(NSArray<Milestone *> *roundtrip, NSError *error) {
        [progressSheet endSheet];
        if (error) {
            NSAlert *err = [NSAlert new];
            err.messageText = NSLocalizedString(@"Unable to update milestone", nil);
            err.informativeText = [error localizedDescription];
            [err beginSheetModalForWindow:sheetParent completionHandler:^(NSModalResponse returnCode) {
                [self finishWithMilestones:nil error:error];
            }];
        } else {
            [self finishWithMilestones:roundtrip error:nil];
        }
    }];
}

- (IBAction)cancel:(id)sender {
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
    [self finishWithMilestones:nil error:nil];
}

- (void)finishWithMilestones:(NSArray *)milestones error:(NSError *)error {
    CFRelease((__bridge CFTypeRef)self); // break retain cycle started in beginInWindow.
    
    if (_completion) {
        _completion(milestones, error);
    }
}

- (void)beginInWindow:(NSWindow *)parentWindow completion:(void (^)(NSArray<Milestone *> *, NSError *error))completion
{
    NSParameterAssert(parentWindow);
    
    CFRetain((__bridge CFTypeRef)self); // create a retain cycle until we finish
    self.completion = completion;
    
    NSWindow *window = self.window;
    [parentWindow beginSheet:window completionHandler:nil];
}

#pragma mark NSOutlineViewDelegate & NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item
{
    if (!item) {
        return [_repoOwners count];
    } else if ([item isKindOfClass:[Account class]]) {
        return [_repos[[(Account *)item identifier]] count];
    } else {
        return 0;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
    if (item) {
        NSArray *repos = _repos[[(Account *)item identifier]];
        return repos[index];
    } else {
        return _repoOwners[index];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [item isKindOfClass:[Account class]];
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item
{
    EditMilestoneRepoCell *cell = [outlineView makeViewWithIdentifier:@"RepoCell" owner:self];
    cell.checkbox.nextStateAfterMixed = NSOnState;
    cell.checkbox.extras_representedObject = item;
    
    if ([item isKindOfClass:[Account class]]) {
        Account *owner = item;
        cell.checkbox.attributedTitle = [[NSAttributedString alloc] initWithString:owner.login attributes:@{NSFontAttributeName : [NSFont boldSystemFontOfSize:[NSFont systemFontSize]]}];
        
        NSSet *repoIdentifierSet = [self repoIdentifiersForOwner:owner];
        if ([repoIdentifierSet isSubsetOfSet:_chosenRepoIdentifiers]) {
            cell.checkbox.state = NSOnState;
        } else if ([repoIdentifierSet intersectsSet:_chosenRepoIdentifiers]) {
            cell.checkbox.state = NSMixedState;
        } else {
            cell.checkbox.state = NSOffState;
        }
        
        cell.checkbox.enabled = ![repoIdentifierSet isSubsetOfSet:_requiredRepoIdentifiers];
        
    } else {
        Repo *repo = item;
        cell.checkbox.attributedTitle = [[NSAttributedString alloc] initWithString:repo.name attributes:@{NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]]}];
        cell.checkbox.state = [_chosenRepoIdentifiers containsObject:repo.identifier] ? NSOnState : NSOffState;
        cell.checkbox.enabled = ![_requiredRepoIdentifiers containsObject:repo.identifier];
    }
    
    return cell;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return NO;
}

@end

@implementation EditMilestoneRepoCell

@end

@implementation EditMilestoneDatePicker

- (void)setEnabled:(BOOL)enabled {
    self.layer.opacity = enabled ? 1.0 : 0.5;
    [super setEnabled:enabled];
}

@end


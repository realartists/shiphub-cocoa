//
//  NewMilestoneController.m
//  ShipHub
//
//  Created by James Howard on 8/5/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "NewMilestoneController.h"

#import "Extras.h"
#import "DataStore.h"
#import "MetadataStore.h"
#import "Repo.h"
#import "Account.h"
#import "ProgressSheet.h"
#import "SemiMixedButton.h"

@interface NewMilestoneRepoCell : NSTableCellView

@property IBOutlet SemiMixedButton *checkbox;

@end

@interface NewMilestoneDatePicker : NSDatePicker
@end

@interface NewMilestoneController () <NSOutlineViewDelegate, NSOutlineViewDataSource>

@property IBOutlet NSTextField *nameField;
@property IBOutlet NSTextField *nameInUseLabel;
@property IBOutlet NSTextView *descriptionText;
@property IBOutlet NSButton *dueButton;
@property IBOutlet NSDatePicker *duePicker;
@property IBOutlet NSOutlineView *repoOutline;
@property IBOutlet NSButton *createButton;

@property (copy) NSString *initialName;
@property Repo *requiredRepo;

@property NSArray<Account *> *repoOwners;
@property NSDictionary<NSNumber *, NSArray<Repo *> *> *repos;

@property NSMutableSet<NSNumber *> *chosenRepoIdentifiers;
@property NSSet<NSNumber *> *requiredRepoIdentifiers;

@property (copy) void (^completion)(NSArray<Milestone *> *, NSError *error);

@end

@implementation NewMilestoneController

- (instancetype)initWithInitialRepos:(NSArray<Repo *> *)initialRepos initialReposAreRequired:(BOOL)required initialName:(NSString *)initialName {
    if (self = [super init]) {
        self.initialName = initialName;
        NSArray *initialIdentifiers = [initialRepos arrayByMappingObjects:^id(id obj) {
            return [obj identifier];
        }];
        
        MetadataStore *ms = [[DataStore activeStore] metadataStore];
        
        NSMutableSet<NSString *> *initialOwners = [NSMutableSet new];
        for (Repo *r in initialRepos) {
            NSString *ownerLogin = [[r.fullName componentsSeparatedByString:@"/"] firstObject];
            [initialOwners addObject:ownerLogin];
        }
        
        _chosenRepoIdentifiers = [NSMutableSet new];
        
        if (initialIdentifiers) {
            [_chosenRepoIdentifiers addObjectsFromArray:initialIdentifiers];
            if (required) {
                _requiredRepoIdentifiers = [NSSet setWithArray:initialIdentifiers];
            }
        }
        
        NSMutableDictionary *repos = [NSMutableDictionary new];
        NSMutableArray *repoOwners = [NSMutableArray new];
        for (Account *repoOwner in [ms repoOwners]) {
            [repoOwners addObject:repoOwner];
            NSMutableArray *accountRepos = [[ms reposForOwner:repoOwner] mutableCopy];
            [accountRepos sortUsingComparator:^NSComparisonResult(Repo *obj1, Repo *obj2) {
                BOOL inInitial1 = [initialIdentifiers containsObject:obj1.identifier];
                BOOL inInitial2 = [initialIdentifiers containsObject:obj2.identifier];
                
                if (inInitial1 && !inInitial2) {
                    return NSOrderedAscending;
                } else if (!inInitial1 && inInitial2) {
                    return NSOrderedDescending;
                } else {
                    return [obj1.name localizedStandardCompare:obj2.name];
                }
            }];
            repos[repoOwner.identifier] = accountRepos;
        }
        
        [repoOwners sortUsingComparator:^NSComparisonResult(Account *obj1, Account *obj2) {
            BOOL inInitial1 = [initialOwners containsObject:obj1.login];
            BOOL inInitial2 = [initialOwners containsObject:obj2.login];
            
            if (inInitial1 && !inInitial2) {
                return NSOrderedAscending;
            } else if (!inInitial1 && inInitial2) {
                return NSOrderedDescending;
            } else {
                return [obj1.login localizedStandardCompare:obj2.login];
            }
        }];
        
        _repoOwners = repoOwners;
        _repos = repos;
    }
    return self;
}

- (NSString *)windowNibName { return @"NewMilestoneController"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _dueButton.state = NSOffState;
    _duePicker.enabled = NO;
    _duePicker.dateValue = [[NSDate date] _ship_dateByAddingDays:@7];
    
    _nameField.stringValue = _initialName ?: @"";
    
    [self validateUI];
    
    [_repoOutline expandItem:nil expandChildren:YES];
}

- (void)validateUI {
    NSString *proposedTitle = [_nameField.stringValue trim];
    
    // check if we already have a milestone with that name
    BOOL dupeName = NO;
    MetadataStore *ms = [[DataStore activeStore] metadataStore];
    for (NSNumber *repoID in _chosenRepoIdentifiers) {
        Repo *r = [ms repoWithIdentifier:repoID];
        Milestone *existing = [ms milestoneWithTitle:proposedTitle inRepo:r];
        if (existing) {
            dupeName = YES;
            break;
        }
    }
    
    _nameInUseLabel.hidden = !dupeName;
    
    _createButton.enabled = !dupeName && [[_nameField.stringValue trim] length] > 0 && [_chosenRepoIdentifiers count] > 0;
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

- (IBAction)createMilestone:(id)sender {
    NSWindow *sheetParent = self.window.sheetParent;
    [sheetParent endSheet:self.window];
    
    ProgressSheet *progressSheet = [ProgressSheet new];
    NSString *msg = nil;
    if (_chosenRepoIdentifiers.count == 1) {
        msg = NSLocalizedString(@"Creating Milestone", nil);
    } else {
        msg = NSLocalizedString(@"Creating Milestones", nil);
    }
    progressSheet.message = msg;
    [progressSheet beginSheetInWindow:sheetParent];
    
    MetadataStore *ms = [[DataStore activeStore] metadataStore];
    NSArray *repos = [[_chosenRepoIdentifiers allObjects] arrayByMappingObjects:^id(id obj) {
        return [ms repoWithIdentifier:obj];
    }];
    
    
    NSMutableDictionary *milestoneInfo = [NSMutableDictionary new];
    milestoneInfo[@"title"] = [_nameField.stringValue trim];
    milestoneInfo[@"milestoneDescription"] = [_descriptionText.string trim];
    if (_dueButton.state == NSOnState) {
        milestoneInfo[@"dueOn"] = _duePicker.dateValue;
    }
    
    [[DataStore activeStore] addMilestone:milestoneInfo inRepos:repos completion:^(NSArray<Milestone *> *milestones, NSError *error) {
        [progressSheet endSheet];
        if (error) {
            NSAlert *err = [NSAlert new];
            err.messageText = NSLocalizedString(@"Unable to create milestone", nil);
            err.informativeText = [error localizedDescription];
            [err beginSheetModalForWindow:sheetParent completionHandler:^(NSModalResponse returnCode) {
                [self finishWithMilestones:nil error:error];
            }];
        } else {
            [self finishWithMilestones:milestones error:nil];
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
    NewMilestoneRepoCell *cell = [outlineView makeViewWithIdentifier:@"RepoCell" owner:self];
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

@implementation NewMilestoneRepoCell

@end

@implementation NewMilestoneDatePicker

- (void)setEnabled:(BOOL)enabled {
    self.layer.opacity = enabled ? 1.0 : 0.5;
    [super setEnabled:enabled];
}

@end

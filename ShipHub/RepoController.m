//
//  RepoController.m
//  ShipHub
//
//  Created by James Howard on 7/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RepoController.h"

#import "Extras.h"
#import "IssueIdentifier.h"
#import "RepoPrefs.h"
#import "RequestPager.h"
#import "SemiMixedButton.h"
#import "Error.h"
#import "RepoSearchField.h"
#import "AvatarManager.h"
#import "ServerConnection.h"

static const NSInteger RepoWhitelistMaxCount = 100;
static NSString *const RepoPrefsEndpoint = @"/api/sync/settings";

@interface RepoCell : NSTableCellView

@property IBOutlet NSButton *checkbox;
@property IBOutlet NSButton *warningButton;

@end

@interface RepoOwnerCell : NSTableCellView

@property IBOutlet SemiMixedButton *checkbox;

@end

@interface RepoController () <NSOutlineViewDelegate, NSOutlineViewDataSource>

@property IBOutlet NSOutlineView *repoOutline;
@property IBOutlet NSButton *cancelButton;
@property IBOutlet NSButton *helpButton;
@property IBOutlet NSButton *reloadButton;
@property IBOutlet NSButton *saveButton;
@property IBOutlet NSProgressIndicator *progressIndicator;
@property IBOutlet NSTextField *emptyField;
@property IBOutlet NSButton *autotrackCheckbox;
@property IBOutlet RepoSearchField *addRepoField;
@property IBOutlet NSButton *addRepoButton;
@property IBOutlet NSView *addRepoError;
@property IBOutlet NSProgressIndicator *addRepoProgressIndicator;

@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL addingRepo;

@property (copy) RepoPrefsLoadedHandler loadedHandler;
@property (copy) RepoPrefsChosenHandler chosenHandler;

@property Auth *auth;

@property (nonatomic) AvatarManager *avatarManager;

@property NSArray<NSDictionary *> *userRepos;
@property NSMutableArray<NSDictionary *> *extraRepos;

@property NSMutableArray<NSDictionary *> *owners;
@property NSMutableDictionary<NSNumber *, NSMutableArray *> *reposByOwner;
@property NSSet *userRepoIdentifiers;
@property NSMutableSet *chosenRepoIdentifiers;

@end

@implementation RepoController

- (void)dealloc {
    dispatch_assert_current_queue(dispatch_get_main_queue());
}

- (NSString *)windowNibName {
    return @"RepoController";
}

- (instancetype)initWithAuth:(Auth *)auth {
    if (self = [super init]) {
        _auth = auth;
    }
    return self;
}

- (AvatarManager *)avatarManager {
    if (!_avatarManager) {
        _avatarManager = [[AvatarManager alloc] initWithHost:_auth.account.ghHost];
    }
    return _avatarManager;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    _addRepoField.auth = _auth;
    _addRepoField.avatarManager = [self avatarManager];
    
    [self loadData];
}

- (void)setCanClose:(BOOL)canClose {
    _canClose = canClose;
    NSWindowStyleMask mask = self.window.styleMask;
    if (canClose && (mask & NSWindowStyleMaskClosable) == 0) {
        mask |= NSWindowStyleMaskClosable;
        self.window.styleMask = mask;
    } else if (!canClose && (mask & NSWindowStyleMaskClosable) != 0) {
        mask ^= NSWindowStyleMaskClosable;
        self.window.styleMask = mask;
    }
}

- (void)setLoading:(BOOL)loading {
    _loading = loading;
    if (loading) {
        [_progressIndicator startAnimation:nil];
    } else {
        [_progressIndicator stopAnimation:nil];
    }
    [_progressIndicator setHidden:!loading];

    [_emptyField setHidden:loading||_owners.count!=0];
    
    [_autotrackCheckbox setEnabled:!loading];
    [_reloadButton setEnabled:!loading];
    [_saveButton setEnabled:!loading];
    [_repoOutline.enclosingScrollView setHidden:loading];
    
    [self updateAddRepoEnabled];
}

- (void)setAddingRepo:(BOOL)adding {
    _addingRepo = adding;
    if (adding) {
        [_addRepoProgressIndicator startAnimation:nil];
    } else {
        [_addRepoProgressIndicator stopAnimation:nil];
    }
    
    [_addRepoProgressIndicator setHidden:adding];
    [_reloadButton setEnabled:!adding];
    [_saveButton setEnabled:!adding];
    
    [self updateAddRepoEnabled];
}

- (NSSet<NSNumber *> *)repoIdentifiersForOwner:(NSDictionary *)owner {
    NSArray *repos = _reposByOwner[owner[@"id"]];
    NSSet *repoIdentifierSet = [NSSet setWithArray:[repos arrayByMappingObjects:^id(id obj) {
        return obj[@"id"];
    }]];
    return repoIdentifierSet;
}

- (void)handleLoadError:(NSError *)error {
    [self setLoading:NO];
    
    ErrLog(@"%@", error);
    
    if (_loadedHandler) {
        RepoPrefsLoadedHandler handler = self.loadedHandler;
        self.loadedHandler = nil;
        handler(YES, error);
        return;
    }
    
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Unable to load GitHub repository data", nil);
    alert.informativeText = [error localizedDescription];
    
    [alert addButtonWithTitle:NSLocalizedString(@"Close", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self cancel:nil];
        } else {
            [self loadData];
        }
    }];
}

- (void)handleAddRepoError:(NSError *)error {
    [self setAddingRepo:NO];
    
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Unable to load GitHub repository data", nil);
    alert.informativeText = [error localizedDescription];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (void)loadAndShowIfNeeded:(RepoPrefsLoadedHandler)loadedHandler chosenHandler:(RepoPrefsChosenHandler)chosenHandler {
    self.loadedHandler = loadedHandler;
    self.chosenHandler = chosenHandler;
    [self window];
    [self loadData];
}

- (void)loadData {
    if (_loading) {
        return;
    }
    
    [self setLoading:YES];
    
    // fetch all of the user's repos
    RequestPager *pager = [[RequestPager alloc] initWithAuth:self.auth];
    [pager fetchPaged:[pager get:@"user/repos"] completion:^(NSArray *data, NSError *err) {
        RunOnMain(^{
            if (err) {
                [self handleLoadError:err];
            } else {
                [self continueWithRepos:data];
            }
        });
        
    }];
}

- (void)continueWithRepos:(NSArray *)repos {
    if (!RepoPrefsEndpoint) {
        [self continueWithRepos:repos prefs:nil];
        return;
    }
    
    // fetch the user's repo prefs
    NSURLComponents *prefsComps = [NSURLComponents new];
    prefsComps.scheme = @"https";
    prefsComps.host = self.auth.account.shipHost;
    prefsComps.path = RepoPrefsEndpoint;
    
    NSMutableURLRequest *prefReq = [[NSMutableURLRequest alloc] initWithURL:prefsComps.URL];
    
    [prefReq setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [_auth addAuthHeadersToRequest:prefReq];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:prefReq completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *http = (id)response;
        
        RunOnMain(^{
            if (http.statusCode == 204) {
                // we have no saved prefs.
            } else if (http.statusCode == 200) {
                // we have prefs
                if (self.loadedHandler) {
                    RepoPrefsLoadedHandler loadedHandler = self.loadedHandler;
                    self.loadedHandler = nil;
                    loadedHandler(NO, nil);
                    return;
                }
            } else {
                [self handleLoadError:error ?: [NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse userInfo:@{ShipErrorUserInfoHTTPResponseCodeKey:@(http.statusCode)}]];
                return;
            }
            
            [self showWindow:nil];
            
            NSError *jsonErr = nil;
            NSDictionary *prefsDict = [data length] > 0 ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr] : nil;
            
            if (jsonErr) {
                [self handleLoadError:jsonErr];
            } else {
                RepoPrefs *prefs = prefsDict ? [[RepoPrefs alloc] initWithDictionary:prefsDict] : nil;
                [self continueWithRepos:repos prefs:prefs];
            }
        });
    }] resume];
}

- (void)continueWithRepos:(NSArray *)repos prefs:(RepoPrefs *)prefs {
    // go out and get repo info for every whitelisted repo
    NSArray *repoReqs = [prefs.whitelist arrayByMappingObjects:^id(id obj) {
        NSURLComponents *comps = [NSURLComponents new];
        comps.scheme = @"https";
        comps.host = _auth.account.ghHost;
        comps.path = [NSString stringWithFormat:@"/repositories/%@", obj];
        return [NSURLRequest requestWithURL:comps.URL];
    }];
    
    [[NSURLSession sharedSession] dataTasksWithRequests:repoReqs completion:^(NSArray<URLSessionResult *> *results) {
        
        RunOnMain(^{
            NSMutableArray *extraRepos = [NSMutableArray arrayWithCapacity:results.count];
            BOOL failed = NO;
            for (URLSessionResult *result in results) {
                NSHTTPURLResponse *http = (id)result.response;
                if (http.statusCode == 404) {
                    continue;
                } else if (result.error) {
                    [self handleLoadError:result.error];
                    failed = YES;
                    break;
                } else if (http.statusCode != 200) {
                    [self handleLoadError:[NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse userInfo:@{ShipErrorUserInfoHTTPResponseCodeKey:@(http.statusCode)}]];
                    failed = YES;
                    break;
                } else {
                    [extraRepos addObject:result.json];
                }
            }
            
            if (!failed) {
                [self updateWithUserRepos:repos extraRepos:extraRepos prefs:prefs];
            }
        });
    }];
}

static NSArray *sortDescriptorsWithKey(NSString *key) {
    return @[[NSSortDescriptor sortDescriptorWithKey:key ascending:YES selector:@selector(localizedStandardCompare:)]];
}

- (void)updateWithUserRepos:(NSArray *)repos extraRepos:(NSArray *)extraRepos prefs:(RepoPrefs *)prefs {
    _userRepos = repos ?: @[];
    _extraRepos = [NSMutableArray arrayWithArray:extraRepos ?: @[]];
    
    _userRepoIdentifiers = [NSSet setWithArray:[_userRepos arrayByMappingObjects:^id(id obj) {
        return obj[@"id"];
    }]];
    
    NSMutableDictionary *ownersById = [NSMutableDictionary new];
    _reposByOwner = [NSMutableDictionary new];
    for (NSDictionary *repo in [_userRepos arrayByAddingObjectsFromArray:_extraRepos]) {
        NSNumber *ownerId = repo[@"owner"][@"id"];
        ownersById[ownerId] = repo[@"owner"];
        NSMutableArray *byOwner = _reposByOwner[ownerId];
        if (!byOwner) {
            _reposByOwner[ownerId] = byOwner = [NSMutableArray new];
        }
        [byOwner addObject:repo];
    }
    
    _owners = [[[ownersById allValues] sortedArrayUsingDescriptors:sortDescriptorsWithKey(@"login")] mutableCopy];
    
    for (NSNumber *owner in _reposByOwner) {
        NSMutableArray *byOwner = _reposByOwner[owner];
        [byOwner sortUsingDescriptors:sortDescriptorsWithKey(@"name")];
    }
    
    _chosenRepoIdentifiers = [NSMutableSet new];
    
    if (prefs) {
        [_chosenRepoIdentifiers addObjectsFromArray:[_userRepos arrayByMappingObjects:^id(id obj) {
            return obj[@"id"];
        }]];
        [_chosenRepoIdentifiers minusSet:[NSSet setWithArray:prefs.blacklist]];
        [_chosenRepoIdentifiers addObjectsFromArray:prefs.whitelist];
    } else {
        [_chosenRepoIdentifiers addObjectsFromArray:[[_userRepos filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"has_issues = YES AND permissions.push = YES"]] arrayByMappingObjects:^id(id obj) {
            return obj[@"id"];
        }]];
    }
    
    _autotrackCheckbox.state = prefs ? (prefs.autotrack ? NSOnState : NSOffState) : YES;
    [_repoOutline reloadData];
    [_repoOutline expandItem:nil expandChildren:YES];
    
    RepoPrefsLoadedHandler loadedHandler = self.loadedHandler;
    
    if (loadedHandler) {
        self.loadedHandler = nil;
        loadedHandler(prefs == nil, nil);
    }
    
    [self setLoading:NO];
}

- (void)updateAddRepoEnabled {
    if (_loading || _addingRepo) {
        _addRepoField.enabled = NO;
        _addRepoButton.enabled = NO;
        return;
    }
    
    NSMutableSet *whitelist = [_chosenRepoIdentifiers mutableCopy];
    [whitelist minusSet:_userRepoIdentifiers];
    
    _addRepoField.enabled = _addRepoButton.enabled = whitelist.count < RepoWhitelistMaxCount;
}

- (IBAction)refresh:(id)sender {
    [self loadData];
}

- (IBAction)cancel:(id)sender {
    if (self.chosenHandler) {
        RepoPrefsChosenHandler handler = self.chosenHandler;
        self.chosenHandler = nil;
        handler(nil);
    }
    [self close];
}

- (IBAction)checkboxDidChange:(id)sender {
    id item = [sender extras_representedObject];
    NSInteger state = [sender state];
    
    if (item[@"login"]) {
        // owner
        NSMutableSet *repoIdentifiers = [[self repoIdentifiersForOwner:item] mutableCopy];
        if (state == NSOnState) {
            [_chosenRepoIdentifiers unionSet:repoIdentifiers];
        } else if (state == NSOffState) {
            [_chosenRepoIdentifiers minusSet:repoIdentifiers];
        }
    } else {
        // repo
        if (state == NSOnState) {
            [_chosenRepoIdentifiers addObject:item[@"id"]];
        } else {
            [_chosenRepoIdentifiers removeObject:item[@"id"]];
        }
    }
    
    [_repoOutline reloadData];
    [self updateAddRepoEnabled];
}

- (IBAction)showRepoWarning:(id)sender {
    NSDictionary *repo = [sender extras_representedObject];
    if (!repo) return;
    
    BOOL missingIssues = [repo[@"has_issues"] boolValue] == NO;
    BOOL missingPush = [repo[@"permissions"][@"push"] boolValue] == NO;
    
    NSString *message = nil;
    
    if (missingIssues && missingPush) {
        message = NSLocalizedString(@"This repository does not have issues enabled.\n\nAdditionally, you do not have push access to this repository, and therefore you will not be able to modify existing pull requests.", nil);
    } else if (missingIssues) {
        message = NSLocalizedString(@"This repository does not have issues enabled. You will not be able to create new issues for this repository.", nil);
    } else {
        message = NSLocalizedString(@"You do not have push access to this repository.\n\nYou will not be able to modify existing Issues or Pull Requests, but you can create new ones.", nil);
    }
    
    NSAlert *alert = [NSAlert new];
    alert.icon = [NSImage imageNamed:NSImageNameCaution];
    alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"%@ is limited.", nil), repo[@"full_name"]];
    alert.informativeText = message;
    
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (IBAction)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.realartists.com/docs/2.0/start.html#selecting-repositories"]];
}

- (IBAction)save:(id)sender {
    NSSet *existingIds = [NSSet setWithArray:[_userRepos arrayByMappingObjects:^id(id obj) {
        return obj[@"id"];
    }]];
    
    NSMutableArray *whitelist = [NSMutableArray new];
    NSMutableArray *blacklist = [NSMutableArray new];
    
    for (NSNumber *ownerId in _reposByOwner) {
        for (NSDictionary *repo in _reposByOwner[ownerId]) {
            NSNumber *repoId = repo[@"id"];
            if ([_chosenRepoIdentifiers containsObject:repoId]) {
                // repo is ON
                if (![existingIds containsObject:repoId]) {
                    [whitelist addObject:repoId];
                }
            } else {
                // repo is OFF
                if ([existingIds containsObject:repoId]) {
                    [blacklist addObject:repoId];
                }
            }
        }
    }
    
    RepoPrefs *prefs = [RepoPrefs new];
    prefs.whitelist = whitelist;
    prefs.blacklist = blacklist;
    prefs.autotrack = _autotrackCheckbox.state == NSOnState;
    
    if (self.chosenHandler) {
        RepoPrefsChosenHandler handler = self.chosenHandler;
        self.chosenHandler = nil;
        [self close];
        handler(prefs);
    } else {
        ServerConnection *conn = [[ServerConnection alloc] initWithAuth:self.auth];
        [conn perform:@"PUT" on:RepoPrefsEndpoint forGitHub:NO headers:nil body:[prefs dictionaryRepresentation] completion:^(id jsonResponse, NSError *error) {
            RunOnMain(^{
                if (error) {
                    NSAlert *alert = [NSAlert new];
                    alert.messageText = NSLocalizedString(@"Failed to save repository selection", nil);
                    alert.informativeText = [error localizedDescription];
                    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
                    [alert runModal];
                }
            });
        }];
        [self close];
    }
}

- (void)showAddRepoError {
    _addRepoError.alphaValue = 0.0;
    _addRepoError.hidden = NO;
    
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
        [context setDuration:0.1];
        _addRepoError.animator.alphaValue = 1.0;
    } completionHandler:^{
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull context) {
            [context setDuration:0.1];
            _addRepoError.animator.alphaValue = 0.0;
        } completionHandler:^{
            _addRepoError.hidden = YES;
        }];
    }];
}

- (void)scrollToRepo:(NSDictionary *)repo {
    NSDictionary *owner = [_owners firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"id = %@", repo[@"owner"][@"id"]]];
    if (!owner) {
        return;
    }
    
    [_repoOutline expandItem:owner];
    
    NSInteger row = [_repoOutline rowForItem:repo];
    if (row != -1) {
        [_repoOutline scrollRowToVisible:row];
    }
}

- (IBAction)addRepo:(id)sender {
    NSString *repoName = [[_addRepoField stringValue] trim];
    NSString *issueIdentifier = [repoName?:@"" stringByAppendingString:@"#0"];
    
    if ([repoName length] == 0) {
        [self.window makeFirstResponder:_addRepoField];
        return;
    }
    
    if (![issueIdentifier isIssueIdentifier]) {
        [self.window makeFirstResponder:_addRepoField];
        [self showAddRepoError];
        return;
    }
    
    NSString *owner = [issueIdentifier issueRepoOwner];
    NSString *name = [issueIdentifier issueRepoName];
    
    // see if the repo is already in our list somewhere
    
    NSDictionary *existingRepo = nil;
    
    for (NSDictionary *anOwner in _owners) {
        NSString *anOwnerLogin = anOwner[@"login"];
        if ([anOwnerLogin caseInsensitiveCompare:owner] == NSOrderedSame) {
            NSArray *repos = _reposByOwner[anOwner[@"id"]];
            for (NSDictionary *aRepo in repos) {
                NSString *aRepoName = aRepo[@"name"];
                if ([aRepoName caseInsensitiveCompare:name] == NSOrderedSame) {
                    existingRepo = aRepo;
                    break;
                }
            }
            break;
        }
    }
    
    if (existingRepo) {
        [_chosenRepoIdentifiers addObject:existingRepo[@"id"]];
        [_repoOutline reloadData];
        [self scrollToRepo:existingRepo];
        return;
    }
    
    [self setAddingRepo:YES];
    
    // see if we can find this repo in github
    NSURLComponents *comps = [NSURLComponents new];
    comps.scheme = @"https";
    comps.host = _auth.account.ghHost;
    comps.path = [NSString stringWithFormat:@"/repos/%@", repoName];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:comps.URL] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        RunOnMain(^{
            [self setAddingRepo:NO];
            
            NSHTTPURLResponse *http = (id)response;
            if (http.statusCode == 404) {
                [self showAddRepoError];
            } else if (http.statusCode == 200 && [data length] > 0) {
                NSError *jsonErr = nil;
                NSDictionary *foundRepo = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
                if (jsonErr||![foundRepo isKindOfClass:[NSDictionary class]]) {
                    [self handleAddRepoError:jsonErr?:[NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse]];
                } else {
                    [self finishAddingRepo:foundRepo];
                }
            } else {
                [self handleAddRepoError:error?:[NSError shipErrorWithCode:ShipErrorCodeUnexpectedServerResponse]];
            }
        });
    }] resume];
}

- (void)finishAddingRepo:(NSDictionary *)foundRepo {
    NSDictionary *owner = foundRepo[@"owner"];
    NSDictionary *existingOwner = [_owners firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"id = %@", owner]];
    if (!existingOwner) {
        [_owners addObject:owner];
        [_owners sortUsingDescriptors:sortDescriptorsWithKey(@"login")];
        _reposByOwner[owner[@"id"]] = [NSMutableArray new];
    }
    
    NSMutableArray *repos = _reposByOwner[owner[@"id"]];
    [repos addObject:foundRepo];
    
    [repos sortUsingDescriptors:sortDescriptorsWithKey(@"name")];
    
    [_chosenRepoIdentifiers addObject:foundRepo[@"id"]];
    [_repoOutline reloadData];
    [self scrollToRepo:foundRepo];
    [self updateAddRepoEnabled];
    
    _addRepoField.stringValue = @"";
    if (_addRepoField.enabled) {
        [self.window makeFirstResponder:_addRepoField];
    }
}

#pragma mark Outline View

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item {
    if (!item) {
        // item is the root
        return [_owners count];
    } else if (item[@"login"]) {
        // item is an owner
        return [_reposByOwner[item[@"id"]] count];
    } else {
        // item is a repo
        return 0;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return [self outlineView:outlineView numberOfChildrenOfItem:item] > 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item {
    if (item) {
        // item is an owner
        return _reposByOwner[item[@"id"]][index];
    } else {
        // item is the root
        return _owners[index];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    return NO;
}

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item
{
    if (item[@"login"]) {
        // owner
        RepoOwnerCell *cell = [outlineView makeViewWithIdentifier:@"RepoOwnerCell" owner:self];
        cell.checkbox.nextStateAfterMixed = NSOnState;
        cell.checkbox.extras_representedObject = item;
        cell.textField.stringValue = item[@"login"] ?: @"";
        
        cell.imageView.image = [[self avatarManager] imageForAccountIdentifier:item[@"id"] avatarURL:item[@"avatar_url"]];
        
        NSSet *repoIdentifierSet = [self repoIdentifiersForOwner:item];
        if ([repoIdentifierSet isSubsetOfSet:_chosenRepoIdentifiers]) {
            cell.checkbox.state = NSOnState;
        } else if ([repoIdentifierSet intersectsSet:_chosenRepoIdentifiers]) {
            cell.checkbox.state = NSMixedState;
        } else {
            cell.checkbox.state = NSOffState;
        }
        
        
        return cell;
    } else {
        // repo
        RepoCell *cell = [outlineView makeViewWithIdentifier:@"RepoCell" owner:self];
        cell.checkbox.title = item[@"name"] ?: @"wat";
        cell.checkbox.extras_representedObject = item;
        cell.warningButton.hidden = [item[@"has_issues"] boolValue] && [item[@"permissions"][@"push"] boolValue];
        cell.warningButton.extras_representedObject = item;
        cell.checkbox.state = [_chosenRepoIdentifiers containsObject:item[@"id"]] ? NSOnState : NSOffState;
        return cell;
    }
}

@end

@implementation RepoCell

@end

@implementation RepoOwnerCell

@end

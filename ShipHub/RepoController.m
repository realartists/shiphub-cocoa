//
//  RepoController.m
//  ShipHub
//
//  Created by James Howard on 7/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RepoController.h"

#import "DataStore.h"
#import "Extras.h"
#import "IssueIdentifier.h"
#import "RepoPrefs.h"
#import "RequestPager.h"
#import "SemiMixedButton.h"
#import "Error.h"
#import "RepoSearchField.h"
#import "AvatarManager.h"
#import "ServerConnection.h"
#import "MetadataStore.h"
#import "SearchFieldToolbarItem.h"

/*
def syncRepos(userRepos, prefs):
  if prefs is None:
    return [r for r in userRepos if r.has_issues and r.permissions.push]
  elif prefs.autoTrack:
    autoTrackedRepos = [r for r in userRepos if r.has_issues and r.permissions.push]
    includedRepos = [r for r in prefs.include if r.permissions.pull]
    return (autoTrackedRepos + includedRepos) - prefs.exclude
  else: # autoTrack = false
    return [r for r in prefs.include if r.permissions.pull]
*/

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

@property IBOutlet NSButton *filterButton;
@property IBOutlet SearchFieldToolbarItem *filterToolbarItem;

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
@property NSArray<NSDictionary *> *filteredOwners;
@property NSDictionary<NSNumber *, NSArray *> *filteredReposByOwner;
@property NSSet *userRepoIdentifiers;
@property NSMutableSet *chosenRepoIdentifiers;
@property NSSet *hiddenLocallyRepoIdentifiers;

@end

@implementation RepoController

- (void)dealloc {
    dispatch_assert_current_queue(dispatch_get_main_queue());
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    
    _filterToolbarItem.searchField.placeholderString = NSLocalizedString(@"Filter Repositories", nil);
    
    NSView *titleBarView = [[self.window standardWindowButton:NSWindowCloseButton] superview];
    
    NSImage *image = [NSImage imageNamed:@"RepoControllerFilterButton"];
    image.template = YES;
    NSButton *button = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 16, 16)];
    [button setButtonType:NSButtonTypeToggle];
    button.bezelStyle = NSRecessedBezelStyle;
    button.bordered = NO;
    button.image = image;
    button.toolTip = NSLocalizedString(@"Filter Repositories", nil);
    button.action = @selector(toggleFilterVisible:);
    button.target = self;
    button.state = NSOffState;
    
    _filterButton = button;
    
    [titleBarView addSubview:button];
    
    [self layoutTitleBar];
    
    _addRepoField.auth = _auth;
    _addRepoField.avatarManager = [self avatarManager];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:self.window];
    
    [self loadData];
}

- (void)windowDidResize:(NSNotification *)note {
    [self layoutTitleBar];
}

- (void)layoutTitleBar {
    NSView *titleBarView = [[self.window standardWindowButton:NSWindowCloseButton] superview];
    CGFloat width = titleBarView.frame.size.width;
    CGFloat height = titleBarView.frame.size.height;
    
    CGRect frame = CGRectMake(width - 5.0 - _filterButton.frame.size.width,
                              height - _filterButton.frame.size.height - 3.0,
                              _filterButton.frame.size.width, _filterButton.frame.size.height);
    _filterButton.frame = frame;
}

- (void)toggleFilterVisible:(id)sender {
    if (self.window.toolbar.isVisible) {
        [self clearFilter];
    }
    [self.window.toolbar setVisible:!self.window.toolbar.visible];
    if (self.window.toolbar.isVisible) {
        [self.window makeFirstResponder:_filterToolbarItem.searchField];
    } else {
        [self updateAddRepoEnabled];
    }
}

- (void)clearFilter {
    NSString *val = [_filterToolbarItem.searchField.stringValue trim];
    if ([val length]) {
        [_filterToolbarItem.searchField setStringValue:@""];
        [self updateFilteredData];
    }
}

- (void)updateFilteredData {
    NSString *filter = [_filterToolbarItem.searchField.stringValue trim];
    if ([filter length] == 0) {
        _filteredOwners = _owners;
        _filteredReposByOwner = _reposByOwner;
    } else {
        NSMutableDictionary *filteredReposByOwner = [NSMutableDictionary new];
        NSMutableArray *filteredOwners = [NSMutableArray new];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"full_name CONTAINS[cd] %@", filter];
        for (NSDictionary *owner in _owners) {
            NSNumber *ownerId = owner[@"id"];
            NSArray *repos = [_reposByOwner[ownerId] filteredArrayUsingPredicate:predicate];
            if ([repos count]) {
                [filteredOwners addObject:owner];
                filteredReposByOwner[ownerId] = repos;
            }
        }
        _filteredOwners = filteredOwners;
        _filteredReposByOwner = filteredReposByOwner;
    }
    
    [_repoOutline reloadData];
    [_repoOutline expandItem:nil expandChildren:YES];
}

- (IBAction)filterSearchFieldDidChange:(id)sender {
    [self updateFilteredData];
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
    // go out and get repo info for every whitelisted repo that isn't in repos
    NSSet *existingIds = [NSSet setWithArray:[repos arrayByMappingObjects:^id(id obj) {
        return obj[@"id"];
    }]];
    
    NSArray *repoReqs = [[prefs.whitelist filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT SELF IN %@", existingIds]] arrayByMappingObjects:^id(id obj) {
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

static NSPredicate *userReposDefaultPredicate() {
    return [NSPredicate predicateWithFormat:@"has_issues = YES AND permissions.push = YES"];
}

- (void)updateWithUserRepos:(NSArray *)repos extraRepos:(NSArray *)extraRepos prefs:(RepoPrefs *)prefs {
    _userRepos = repos ?: @[];
    _extraRepos = [NSMutableArray arrayWithArray:extraRepos ?: @[]];
    
    if (!_auth.temporary) {
        _hiddenLocallyRepoIdentifiers = [NSSet setWithArray:[[[[DataStore activeStore] metadataStore] hiddenRepos] arrayByMappingObjects:^id(Repo *obj) {
            return obj.identifier;
        }]];
    }
    
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
    
    NSArray *defaultRepos = [_userRepos filteredArrayUsingPredicate:userReposDefaultPredicate()];
    
    NSSet *defaultIds = [NSSet setWithArray:[defaultRepos arrayByMappingObjects:^id(id obj) {
        return obj[@"id"];
    }]];
    
    if (!prefs) {
        [_chosenRepoIdentifiers unionSet:defaultIds];
    } else if (prefs.autotrack) {
        [_chosenRepoIdentifiers unionSet:defaultIds];
        [_chosenRepoIdentifiers unionSet:[NSSet setWithArray:prefs.whitelist]];
        [_chosenRepoIdentifiers minusSet:[NSSet setWithArray:prefs.blacklist]];
    } else /* prefs.autotrack == NO */ {
        [_chosenRepoIdentifiers unionSet:[NSSet setWithArray:prefs.whitelist]];
    }
    
    _autotrackCheckbox.state = prefs ? (prefs.autotrack ? NSOnState : NSOffState) : YES;
    
    [self updateFilteredData]; // will also reload outline and expand all.
    
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
    
    if (_addRepoField.enabled && ![_addRepoField isFirstResponder]) {
        [self.window makeFirstResponder:_addRepoField];
    }
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
    NSInteger state = [(NSButton *)sender state];
    
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
    BOOL archived = [repo[@"archived"] boolValue];
    BOOL missingPush = [repo[@"permissions"][@"push"] boolValue] == NO;
    BOOL hiddenLocally =  [_hiddenLocallyRepoIdentifiers containsObject:repo[@"id"]];
    
    NSString *message = nil;
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"%@ is limited.", nil), repo[@"full_name"]];
    
    if (archived) {
        title = [NSString stringWithFormat:NSLocalizedString(@"%@ is archived.", nil), repo[@"full_name"]];
        message = NSLocalizedString(@"This repository is archived on GitHub. Neither Issues nor Pull Requests can be created or modified, and therefore it is unavailable for use with Ship.", nil);
    } else if (hiddenLocally) {
        title = [NSString stringWithFormat:NSLocalizedString(@"%@ is hidden locally.", nil), repo[@"full_name"]];
        message = NSLocalizedString(@"This repository will sync, but it is marked as hidden. To view issues in this repository, select it in the sidebar of the Overview window, and click the button to unhide it.", nil);
    } else if (missingIssues && missingPush) {
        message = NSLocalizedString(@"This repository does not have issues enabled.\n\nAdditionally, you do not have push access to this repository, and therefore you will not be able to modify existing pull requests.", nil);
    } else if (missingIssues) {
        message = NSLocalizedString(@"This repository does not have issues enabled. You will not be able to create new issues for this repository.", nil);
    } else {
        message = NSLocalizedString(@"You do not have push access to this repository.\n\nYou will not be able to modify existing Issues or Pull Requests, but you can create new ones.", nil);
    }
    
    NSAlert *alert = [NSAlert new];
    alert.icon = [NSImage imageNamed:NSImageNameCaution];
    alert.messageText = title;
    alert.informativeText = message;
    
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}

- (IBAction)showHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.realartists.com/docs/2.0/start.html#selecting-repositories"]];
}

- (IBAction)save:(id)sender {
    NSSet *defaultIds = [NSSet setWithArray:[[_userRepos filteredArrayUsingPredicate:userReposDefaultPredicate()] arrayByMappingObjects:^id(id obj) {
        return obj[@"id"];
    }]];
    
    NSMutableSet *whitelist = [NSMutableSet new];
    NSMutableSet *blacklist = [NSMutableSet new];
    BOOL autotrack = _autotrackCheckbox.state == NSOnState;
    
    for (NSNumber *ownerId in _reposByOwner) {
        for (NSDictionary *repo in _reposByOwner[ownerId]) {
            NSNumber *repoId = repo[@"id"];
            if ([_chosenRepoIdentifiers containsObject:repoId]) {
                // repo is ON
                if (![defaultIds containsObject:repoId] || !autotrack) {
                    [whitelist addObject:repoId];
                }
            } else {
                // repo is OFF
                if ([defaultIds containsObject:repoId] && autotrack) {
                    [blacklist addObject:repoId];
                }
            }
        }
    }
    
    RepoPrefs *prefs = [RepoPrefs new];
    prefs.whitelist = [whitelist allObjects];
    prefs.blacklist = [blacklist allObjects];
    prefs.autotrack = autotrack;
    
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

- (void)controlTextDidEndEditing:(NSNotification *)note {
    NSControl *sender = [note object];
    if (sender == _addRepoField) {
        NSDictionary *dict  = [note userInfo];
        NSNumber  *reason = [dict objectForKey: @"NSTextMovement"];
        NSInteger code = [reason integerValue];
        
        if (code == NSTextMovementReturn) {
            [self addRepo:sender];
        }
    }
}

- (IBAction)addRepo:(id)sender {
    [self clearFilter];
    
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
    NSDictionary *existingOwner = [_owners firstObjectMatchingPredicate:[NSPredicate predicateWithFormat:@"id = %@", owner[@"id"]]];
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
        return [_filteredOwners count];
    } else if (item[@"login"]) {
        // item is an owner
        return [_filteredReposByOwner[item[@"id"]] count];
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
        return _filteredReposByOwner[item[@"id"]][index];
    } else {
        // item is the root
        return _filteredOwners[index];
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
        BOOL archived = [item[@"archived"] boolValue];
        NSString *title = item[@"name"] ?: @"";
        if (archived) {
            title = [NSString stringWithFormat:@"%@ %@", title, NSLocalizedString(@"[archived]", nil)];
        }
        RepoCell *cell = [outlineView makeViewWithIdentifier:@"RepoCell" owner:self];
        cell.checkbox.title = title;
        cell.checkbox.extras_representedObject = item;
        BOOL hiddenLocally = [_chosenRepoIdentifiers containsObject:item[@"id"]] && [_hiddenLocallyRepoIdentifiers containsObject:item[@"id"]];
        cell.warningButton.hidden = [item[@"has_issues"] boolValue] && [item[@"permissions"][@"push"] boolValue] && !hiddenLocally && !archived;
        cell.warningButton.extras_representedObject = item;
        cell.checkbox.state = [_chosenRepoIdentifiers containsObject:item[@"id"]] && !archived ? NSOnState : NSOffState;
        cell.checkbox.enabled = !archived;
        return cell;
    }
}

@end

@implementation RepoCell

@end

@implementation RepoOwnerCell

@end

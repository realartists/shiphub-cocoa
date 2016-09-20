//
//  SubscriptionController.m
//  ShipHub
//
//  Created by James Howard on 9/19/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "SubscriptionController.h"

#import "DataStore.h"
#import "ServerConnection.h"
#import "Extras.h"
#import "AvatarManager.h"

@interface SubscriptionCellView : NSTableCellView

@property NSDictionary *account;

@property (assign) IBOutlet NSImageView *imageView;
@property (assign) IBOutlet NSTextField *login;
@property (assign) IBOutlet NSTextField *accountType;

@property (assign) IBOutlet NSTextField *mainLabel;
@property (assign) IBOutlet NSButton *actionButton;

@end

@interface UnsubscribedOrgCellView : SubscriptionCellView

@property (assign) IBOutlet NSTextField *secondaryLabel;

@end

@interface UnsubscribedUserCellView : SubscriptionCellView

@end

@interface SubscribedCellView : SubscriptionCellView

@end

@interface SubscriptionController () <NSTableViewDataSource, NSTableViewDelegate>

@property IBOutlet NSTextField *label;
@property IBOutlet NSTableView *table;
@property IBOutlet NSProgressIndicator *progress;

@property NSArray *subscriptions;

@end

@implementation SubscriptionController

- (NSString *)windowNibName { return @"SubscriptionController"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:DataStoreBillingStateDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showWindow:(id)sender {
    [[self window] makeKeyAndOrderFront:sender];
    [self refresh];
}

- (void)refresh {
    DataStore *store = [DataStore activeStore];
    ServerConnection *conn = [store serverConnection];
    
    _progress.hidden = NO;
    [_progress startAnimation:nil];
    
    _subscriptions = nil;
    [_table reloadData];
    
    [conn perform:@"GET" on:@"/billing/accounts" body:nil completion:^(id jsonResponse, NSError *error) {
        RunOnMain(^{
            [_progress stopAnimation:nil];
            _progress.hidden = YES;
            
            if (error) {
                [self presentError:error];
            } else {
                _subscriptions = jsonResponse;
                [_table reloadData];
            }
        });
    }];
}

- (IBAction)showHelp:(id)sender {
    NSURL *URL = [NSURL URLWithString:@"https://beta.realartists.com/pricing.html"];
    [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (IBAction)subscriptionAction:(id)sender {
    NSInteger row = [_table rowForView:sender];
    NSDictionary *sub = _subscriptions[row];
    DebugLog(@"%@", sub);
    
    NSString *action = sub[@"actionURL"];
    NSURL *URL = [NSURL URLWithString:action];
    
    [[NSWorkspace sharedWorkspace] openURL:URL];
}

- (BOOL)presentError:(NSError *)error {
    NSAlert *alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Failed to load subscription data.", nil);
    alert.informativeText = [error localizedDescription];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
    
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            [self close];
        } else {
            [self refresh];
        }
    }];
    
    return YES;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return _subscriptions.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    SubscriptionCellView *cell = nil;
    NSDictionary *sub = _subscriptions[row];
    
    NSDictionary *account = sub[@"account"];
    NSString *accountType = account[@"type"];
    
    BOOL subscribed = [sub[@"subscribed"] boolValue];
    
    NSString *cellIdentifier;
    if (subscribed) {
        cellIdentifier = @"Subscribed";
    } else if ([accountType isEqualToString:@"organization"]) {
        cellIdentifier = @"UnsubscribedOrg";
    } else {
        cellIdentifier = @"UnsubscribedUser";
    }
    cell = [tableView makeViewWithIdentifier:cellIdentifier owner:self];
    
    cell.actionButton.enabled = [sub[@"canEdit"] boolValue];
    
    NSTextField *line1 = cell.mainLabel;
    NSTextField *line2 = [cell respondsToSelector:@selector(secondaryLabel)] ? [(id)cell secondaryLabel] : nil;
    
    NSArray *pricingLines = sub[@"pricingLines"];
    line1.stringValue = pricingLines.count > 0 ? pricingLines[0] : @"";
    line2.stringValue = pricingLines.count > 1 ? pricingLines[1] : @"";
    
    if ([accountType isEqualToString:@"organization"]) {
        cell.accountType.stringValue = NSLocalizedString(@"Organization", nil);
    } else {
        cell.accountType.stringValue = NSLocalizedString(@"Personal", nil);
    }
    
    NSURL *avatarURL = account[@"avatarURL"] ? [NSURL URLWithString:account[@"avatarURL"]] : nil;
    cell.imageView.image = [[AvatarManager activeManager] imageForAccountIdentifier:account[@"identifier"] avatarURL:avatarURL];
    
    return cell;
}

@end

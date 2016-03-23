//
//  NetworkStateWindow.m
//  Ship
//
//  Created by James Howard on 8/22/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "NetworkStateWindow.h"

#import "Reachability.h"
#import "DataStore.h"
#import "Auth.h"
#import "Defaults.h"


@interface NetworkStateWindow ()

@property NSButton *stateButton;

@end

@implementation NetworkStateWindow

- (NSView *)titleBarView {
    return [[self standardWindowButton:NSWindowCloseButton] superview];
}

- (id)init {
    if (self = [super init]) {
        [self setupNetworkState];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        [self setupNetworkState];
    }
    return self;
}

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    if (self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag]) {
        [self setupNetworkState];
    }
    return self;
}

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag screen:(NSScreen *)screen
{
    if (self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag screen:screen]) {
        [self setupNetworkState];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateNetworkState:(NSNotification *)note {
    BOOL reachable = [note.userInfo[ReachabilityKey] boolValue];
    _stateButton.hidden = reachable;
}

- (void)setupNetworkState {
    if (ServerEnvironmentLocal == DefaultsServerEnvironment())
        return;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateNetworkState:) name:ReachabilityDidChangeNotification object:nil];
    
    NSImage *image = [NSImage imageNamed:@"OfflineTemplate"];
    [image setTemplate:YES];
    _stateButton = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 26, 16)];
    _stateButton.bezelStyle = NSRecessedBezelStyle;
    _stateButton.bordered = NO;
    _stateButton.image = image;
    _stateButton.toolTip = NSLocalizedString(@"Currently Offline", nil);
    _stateButton.action = @selector(attemptGoOnline:);
    _stateButton.target = self;
    _stateButton.hidden = [[Reachability sharedInstance] receivedFirstUpdate] && [[Reachability sharedInstance] isReachable];
    
    NSView *titleBarView = [self titleBarView];
    
    [titleBarView addSubview:_stateButton];
    
    [self layoutStateButton];
}

- (void)layoutIfNeeded {
    [super layoutIfNeeded];
    [self layoutStateButton];
}

- (void)layoutStateButton {
    NSView *titleBarView = [self titleBarView];
    
    CGFloat width = titleBarView.frame.size.width;
    CGFloat height = titleBarView.frame.size.height;

    CGRect frame = CGRectMake(width - 5.0 - _stateButton.frame.size.width,
                              height - _stateButton.frame.size.height - 3.0,
                              _stateButton.frame.size.width, _stateButton.frame.size.height);
    _stateButton.frame = frame;
}

- (void)attemptGoOnline:(id)sender {
    Reachability *reach = [Reachability sharedInstance];
    if (reach.forceOffline) {
        reach.forceOffline = NO;
        return;
    }
    
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Currently Offline", nil);
    
    NSString *host = [[[[DataStore activeStore] auth] account] shipHost];
    NSNumber *port = @443;
    alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"%@ on port %@ is not currently reachable from your machine.\n\nWhile offline you have full access to your database, as of the last time you were online. You may continue to make changes to problems as well as create new problems.\n\nOnce connectivity to the server is re-establised, your database will be automatically synchronized with the server.", nil), host, port];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
    [alert runModal];
}

@end

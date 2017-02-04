//
//  ServerChooser.m
//  ShipHub
//
//  Created by James Howard on 7/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "ServerChooser.h"

#import "Defaults.h"
#import "Extras.h"

@interface ServerChooser ()

@property IBOutlet NSTextField *ghHost;
@property IBOutlet NSTextField *shipHost;

@property IBOutlet NSButton *privateReposCheck;

@property IBOutlet NSButton *okButton;

@end

@implementation ServerChooser

- (NSString *)nibName { return @"ServerChooser"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    _shipHost.stringValue = DefaultShipHost();
    _ghHost.stringValue = DefaultGHHost();
}

- (void)controlTextDidChange:(NSNotification *)obj {
    _okButton.enabled = [[_ghHost.stringValue trim] length] > 0;
}

- (IBAction)submit:(id)sender {
    NSString *ghHost = [_ghHost.stringValue trim];
    NSString *shipHost = [_shipHost.stringValue trim];
    
    if ([shipHost length] == 0) {
        shipHost = ghHost;
    }
    
    BOOL publicOnly = _privateReposCheck.state == NSOffState;
    
    [_delegate serverChooser:self didChooseShipHost:shipHost ghHost:ghHost publicReposOnly:publicOnly];
}

- (IBAction)cancel:(id)sender {
    [_delegate serverChooserDidCancel:self];
}

- (IBAction)reset:(id)sender {
    _privateReposCheck.state = NSOnState;
    _shipHost.stringValue = DefaultShipHost();
    _ghHost.stringValue = DefaultGHHost();
    
    [_delegate serverChooser:self didChooseShipHost:DefaultShipHost() ghHost:DefaultGHHost() publicReposOnly:NO];
}

- (NSString *)shipHostValue {
    return _shipHost.stringValue;
}

- (NSString *)ghHostValue {
    return _ghHost.stringValue;
}

- (void)setShipHostValue:(NSString *)shipHostValue {
    [self view];
    
    _shipHost.stringValue = shipHostValue ?: @"";
}

- (void)setGhHostValue:(NSString *)ghHostValue {
    [self view];
    
    _ghHost.stringValue = ghHostValue ?: @"";
}

- (void)setPublicReposOnly:(BOOL)publicReposOnly {
    [self view];
    
    _privateReposCheck.state = publicReposOnly ? NSOffState : NSOnState;
}

- (BOOL)publicReposOnly {
    return _privateReposCheck.state == NSOffState;
}

- (IBAction)reposChanged:(id)sender {
    
}

@end

//
//  WelcomeController.m
//  ShipHub
//
//  Created by James Howard on 8/15/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "WelcomeController.h"

#import "AuthController.h"
#import "BasicAuthController.h"
#import "Extras.h"
#import "NavigationController.h"
#import "ServerChooser.h"
#import "WebAuthController.h"

@interface WelcomeController () <ServerChooserDelegate, NSPopoverDelegate>

@property IBOutlet NSButton *infoButton;
@property IBOutlet NSButton *serverButton;

@property NSPopover *popover;

@end

@implementation WelcomeController

- (NSString *)nibName {
    return @"WelcomeController";
}

- (id)init {
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Real Artists Ship", nil);
        
        NSMutableAttributedString *shipString = [NSMutableAttributedString new];
        
        NSFont *font = [NSFont fontWithName:@"Helvetica-Bold" size:24.0];
        NSFont *italic = [[NSFontManager sharedFontManager] convertFont:font toHaveTrait:NSItalicFontMask];
        
        [shipString appendAttributes:@{ NSFontAttributeName : font,
                                        NSForegroundColorAttributeName : [NSColor whiteColor] } format:@"Real Artists "];
        [shipString appendAttributes:@{ NSFontAttributeName : italic,
                                        NSForegroundColorAttributeName : [NSColor ra_orange] } format:@"Ship"];
        
        NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
        para.alignment = NSTextAlignmentCenter;
        [shipString addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, shipString.length)];
        
        self.navigationItem.attributedTitle = shipString;
        
        _shipHost = DefaultShipHost();
        _ghHost = DefaultGHHost();
    }
    return self;
}

- (IBAction)start:(id)sender {
    if ([_ghHost isEqualToString:@"api.github.com"]) {
        WebAuthController *web = [[WebAuthController alloc] initWithAuthController:[AuthController authControllerForViewController:self]];
        web.shipHost = _shipHost;
        [web show];
    } else {
        BasicAuthController *basic = [BasicAuthController new];
        basic.shipHost = _shipHost;
        basic.ghHost = _ghHost;
        [self.navigationController pushViewController:basic animated:YES];
    }
}

- (IBAction)moreInformation:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://beta.realartists.com"]];
}

- (IBAction)showServerChooser:(id)sender {
    ServerChooser *chooser = [ServerChooser new];
    chooser.delegate = self;
    chooser.ghHostValue = _ghHost;
    chooser.shipHostValue = _shipHost;
    
    _popover = [[NSPopover alloc] init];
    _popover.delegate = self;
    _popover.behavior = NSPopoverBehaviorTransient;
    _popover.contentViewController = chooser;
    _popover.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    
    [_popover showRelativeToRect:_serverButton.bounds ofView:_serverButton preferredEdge:NSMaxYEdge];
}

- (void)serverChooser:(ServerChooser *)chooser didChooseShipHost:(NSString *)shipHost ghHost:(NSString *)ghHost {
    _shipHost = shipHost;
    _ghHost = ghHost;
    
    [_popover performClose:nil];
    _popover = nil;
}

- (void)serverChooserDidCancel:(ServerChooser *)chooser {
    [_popover performClose:nil];
    _popover = nil;
}

@end

//
//  WelcomeViewController.m
//  Ship
//
//  Created by James Howard on 8/26/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "WelcomeViewController.h"
#import "NavigationController.h"
#import "SignInController.h"
#import "Extras.h"

@interface WelcomeViewController ()

@property IBOutlet NSButton *infoButton;

@end

@implementation WelcomeViewController

- (NSString *)nibName {
    return @"WelcomeViewController";
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
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSMutableAttributedString *str = [_infoButton.attributedTitle mutableCopy];
    [str addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, str.length)];
    
    _infoButton.attributedTitle = str;
}

- (IBAction)signIn:(id)sender {
    SignInController *vc = [SignInController new];
    vc.authController = self.authController;
    [self.navigationController pushViewController:vc animated:YES];
}

- (IBAction)moreInfo:(id)sender {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSDictionary *info = [mainBundle infoDictionary];
    NSString *infoURL = info[@"MoreInfoURL"] ?: @"https://www.realartists.com/index.html";
    
    NSURL *URL = [NSURL URLWithString:infoURL];
    
    if (URL) {
        [[NSWorkspace sharedWorkspace] openURL:URL];
    }
}

@end

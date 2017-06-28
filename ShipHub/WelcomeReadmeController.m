//
//  WelcomeReadmeController.m
//  ShipHub
//
//  Created by James Howard on 6/27/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "WelcomeReadmeController.h"

#import "NavigationController.h"
#import "AuthController.h"
#import "WebAuthController.h"
#import "BasicAuthController.h"

@interface WelcomeReadmeController ()

@property IBOutlet NSTextView *readmeView;

@end

@implementation WelcomeReadmeController

- (NSString *)nibName {
    return @"WelcomeReadmeController";
}

- (id)init {
    if (self = [super init]) {
        self.title = NSLocalizedString(@"Privacy Notice", nil);
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *URL = [[NSBundle mainBundle] URLForResource:@"README" withExtension:@"rtf"];
    NSDictionary *opts = @{ NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType, NSCharacterEncodingDocumentAttribute : @(NSUTF8StringEncoding) };
    NSAttributedString *str = [[NSAttributedString alloc] initWithURL:URL options:opts documentAttributes:NULL error:NULL];
    [_readmeView.textStorage setAttributedString:str];
    
    _readmeView.textContainerInset = CGSizeMake(10.0, 14.0);
}

- (IBAction)start:(id)sender {
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"ReadmeShown"];
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

- (IBAction)cancel:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end

//
//  PRPostMergeController.m
//  ShipHub
//
//  Created by James Howard on 5/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRPostMergeController.h"

#import "Issue.h"
#import "DataStore.h"
#import "Extras.h"

@interface PRPostMergeController ()

@property IBOutlet NSTextField *infoLabel;
@property IBOutlet NSButton *deleteButton;

@end

@implementation PRPostMergeController

- (NSString *)windowNibName { return @"PRPostMergeController"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    _deleteButton.state = NSOffState;
}

- (void)setIssue:(Issue *)issue {
    [self window];
    
    _issue = issue;
    
    if ([issue.base[@"repo"][@"fullName"] isEqualToString:issue.head[@"repo"][@"fullName"]]
        && ![issue.head[@"repo"][@"defaultBranch"] isEqualToString:issue.head[@"ref"]])
    {
        
        _infoLabel.hidden = NO;
        _deleteButton.state = NSOffState;
        _deleteButton.hidden = NO;
        
        NSMutableAttributedString *infoStr = [NSMutableAttributedString new];
        
        NSDictionary *baseAttrs = @{ NSFontAttributeName: [NSFont systemFontOfSize:13.0] };
        NSDictionary *refAttrs = @{ NSFontAttributeName: [NSFont fontWithName:@"menlo" size:12.0] };
        
        [infoStr appendAttributes:baseAttrs format:NSLocalizedString(@"The ", nil)];
        [infoStr appendAttributes:refAttrs format:@"%@", issue.head[@"ref"]];
        [infoStr appendAttributes:baseAttrs format:NSLocalizedString(@" branch can be safely deleted.", nil)];
        
        
        NSMutableParagraphStyle *para = [NSMutableParagraphStyle new];
        para.lineBreakMode = NSLineBreakByTruncatingTail;
        [infoStr addAttribute:NSParagraphStyleAttributeName value:para range:NSMakeRange(0, infoStr.length)];
        
        _infoLabel.attributedStringValue = infoStr;   
    } else {
        _infoLabel.hidden = YES;
        _deleteButton.state = NSOffState;
        _deleteButton.hidden = YES;
    }
}

- (IBAction)ok:(id)sender {
    if (_deleteButton.state == NSOnState) {
        [[DataStore activeStore] deletePullRequestBranch:_issue completion:nil];
    }
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (void)beginSheetModalForWindow:(NSWindow *)parentWindow completion:(dispatch_block_t)completion
{
    CFRetain((__bridge CFTypeRef)self);
    [parentWindow beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        if (completion) completion();
        CFRelease((__bridge CFTypeRef)self);
    }];
}

@end

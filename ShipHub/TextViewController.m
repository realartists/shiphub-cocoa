//
//  TextViewController.m
//  Ship
//
//  Created by James Howard on 6/15/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "TextViewController.h"

@interface TextViewController ()

@property (strong) IBOutlet NSTextView *textView;

@end

@implementation TextViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _textView.textContainerInset = CGSizeMake(10.0, 10.0);
}

- (void)setAttributedStringValue:(NSAttributedString *)attributedStringValue {
    [self view];
    [_textView.textStorage setAttributedString:attributedStringValue];
}

- (NSAttributedString *)attributedStringValue {
    return _textView.attributedString;
}

- (IBAction)scrollToBeginningOfDocument:(id)sender {
    [_textView.enclosingScrollView scrollToBeginningOfDocument:sender];
}

@end

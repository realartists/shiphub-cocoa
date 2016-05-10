//
//  CompactIssueCellViewController.m
//  ShipHub
//
//  Created by James Howard on 5/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "CompactIssueCellViewController.h"

#import "Extras.h"
#import "Issue.h"
#import "LabelsView.h"


@interface CompactIssueRowView : NSTableRowView

@property (weak) CompactIssueCellViewController *controller;

@end

@interface CompactIssueCellViewController ()

@property IBOutlet NSTextField *titleField;
@property IBOutlet NSTextField *infoField;
@property IBOutlet NSTextField *commentsField;
@property IBOutlet LabelsView *labelsView;

@end

@implementation CompactIssueCellViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    CompactIssueRowView *view = (id)self.view;
    view.controller = self;
}

- (void)setIssue:(Issue *)issue {
    _issue = issue;
    _titleField.stringValue = issue.title;
    if (issue.commentsCount > 0) {
        _commentsField.stringValue = [NSString stringWithFormat:@"💬%tu", issue.commentsCount];
    } else {
        _commentsField.stringValue = @"";
    }
    _labelsView.labels = issue.labels;
}

- (void)updateDisplay {
    CompactIssueRowView *view = (id)self.view;
    BOOL emph = view.emphasized;
    BOOL sel = view.selected;
    
    if (sel && emph) {
        _titleField.textColor = [NSColor whiteColor];
        _infoField.textColor = [NSColor whiteColor];
        _commentsField.textColor = [NSColor whiteColor];
        _labelsView.highlighted = YES;
    } else {
        _titleField.textColor = [NSColor blackColor];
        _infoField.textColor = [NSColor blackColor];
        _commentsField.textColor = [NSColor extras_controlBlue];
        _labelsView.highlighted = NO;
    }
}

@end

@implementation CompactIssueRowView

- (void)setEmphasized:(BOOL)emphasized {
    [super setEmphasized:emphasized];
    [_controller updateDisplay];
}

- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [_controller updateDisplay];
}

- (void)setNextRowSelected:(BOOL)nextRowSelected {
    [super setNextRowSelected:nextRowSelected];
    [self setNeedsDisplay:YES];
}

- (void)drawSeparatorInRect:(NSRect)dirtyRect {
    
    CGRect r = CGRectMake(0.0, self.bounds.size.height - 1.0, self.bounds.size.width, 1.0);
    if (self.selected || self.isNextRowSelected) {
        [[NSColor whiteColor] set];
    } else {
        [[NSColor extras_tableSeparator] set];
        r.origin.x += 10.0;
        r.size.width -= 10.0;
    }
    
    NSRectFill(r);
}

@end

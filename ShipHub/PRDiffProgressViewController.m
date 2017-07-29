//
//  PRDiffProgressViewController.m
//  ShipHub
//
//  Created by James Howard on 7/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRDiffProgressViewController.h"

#import "Extras.h"

@interface PRDiffProgressViewController ()

@property IBOutlet NSTextField *label;
@property IBOutlet NSProgressIndicator *indicator;
@property IBOutlet NSButton *cancelButton;

@end

@implementation PRDiffProgressViewController

- (void)dealloc {
    self.progress = nil;
}

- (NSString *)nibName { return @"PRDiffProgressViewController"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateProgress];
}

- (void)viewDidAppear {
    [super viewDidAppear];
}

- (void)setProgress:(NSProgress *)progress {
    if (_progress != progress) {
        if (_progress) {
            [_progress removeObserver:self forKeyPath:@"totalUnitCount" context:NULL];
            [_progress removeObserver:self forKeyPath:@"completedUnitCount" context:NULL];
        }
        _progress = progress;
        if (_progress) {
            [_progress addObserver:self forKeyPath:@"totalUnitCount" options:0 context:NULL];
            [_progress addObserver:self forKeyPath:@"completedUnitCount" options:0 context:NULL];
        }
        [self updateProgress];
    }
}

- (void)updateProgress {
    if (_progress.indeterminate) {
        [_indicator setIndeterminate:YES];
    } else {
        [_indicator setIndeterminate:NO];
        _indicator.minValue = 0.0;
        _indicator.maxValue = 1.0;
        _indicator.doubleValue = _progress.fractionCompleted;
    }
    _cancelButton.hidden = _progress == nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (object == _progress) {
        RunOnMain(^{
            [self updateProgress];
        });
    }
}

- (IBAction)cancel:(id)sender {
    [_progress cancel];
}

@end

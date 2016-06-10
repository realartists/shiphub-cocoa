//
//  DownloadBarViewController.m
//  ShipHub
//
//  Created by James Howard on 6/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "DownloadBarViewController.h"

#import "Extras.h"

@interface DownloadBarViewController ()

@property IBOutlet NSProgressIndicator *indicator;
@property IBOutlet NSTextField *label;
@property IBOutlet NSButton *cancelButton;

@end

@implementation DownloadBarViewController

- (NSString *)nibName {
    return @"DownloadBarViewController";
}

- (void)dealloc {
    self.progress = nil;
}

- (void)setProgress:(NSProgress *)progress {
    if (_progress != progress) {
        if (_progress) {
            [_progress removeObserver:self forKeyPath:@"totalUnitCount" context:NULL];
            [_progress removeObserver:self forKeyPath:@"completedUnitCount" context:NULL];
            [_progress removeObserver:self forKeyPath:@"localizedDescription" context:NULL];
        }
        _progress = progress;
        if (_progress) {
            [_progress addObserver:self forKeyPath:@"totalUnitCount" options:0 context:NULL];
            [_progress addObserver:self forKeyPath:@"completedUnitCount" options:0 context:NULL];
            [_progress addObserver:self forKeyPath:@"localizedDescription" options:0 context:NULL];
        }
        [self updateProgress];
    }
}

- (void)updateProgress {
    _indicator.doubleValue = _progress.fractionCompleted;
    if (_progress.localizedDescription)
        _label.stringValue = _progress.localizedDescription ?: @"";
    _cancelButton.hidden = _progress == nil;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    if (object == _progress) {
        RunOnMain(^{
            [self updateProgress];
        });
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _indicator.minValue = 0.0;
    _indicator.maxValue = 1.0;
    [self updateProgress];
}

- (IBAction)cancel:(id)sender {
    [self.progress cancel];
}

@end

//
//  TrackingProgressSheet.m
//  ShipHub
//
//  Created by James Howard on 4/4/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "TrackingProgressSheet.h"

#import "Extras.h"

@interface TrackingProgressSheet ()

@property IBOutlet NSProgressIndicator *indicator;
@property IBOutlet NSTextField *label;
@property IBOutlet NSButton *cancelButton;

@end

@implementation TrackingProgressSheet

- (void)dealloc {
    self.progress = nil;
}

- (NSString *)windowNibName { return @"TrackingProgressSheet"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    [self updateProgress];
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
    if (_progress.indeterminate) {
        [_indicator setIndeterminate:YES];
    } else {
        [_indicator setIndeterminate:NO];
        _indicator.minValue = 0.0;
        _indicator.maxValue = 1.0;
        _indicator.doubleValue = _progress.fractionCompleted;
    }
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

- (void)beginSheetInWindow:(NSWindow *)window {
    if (self.window.sheetParent) return;
    
    [window beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        [_indicator stopAnimation:nil];
    }];
    [_indicator startAnimation:nil];
}

- (void)endSheet {
    [self.window.sheetParent endSheet:self.window];
}

- (IBAction)cancel:(id)sender {
    [_progress cancel];
    [self endSheet];
}

@end

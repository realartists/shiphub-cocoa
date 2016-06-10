//
//  MultiDownloadProgress.m
//  ShipHub
//
//  Created by James Howard on 6/10/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "MultiDownloadProgress.h"

@interface MultiDownloadProgress ()

@property NSMutableArray *multiChildren; // avoid children as superclass uses _children as a private ivar

@end

@implementation MultiDownloadProgress

- (void)dealloc {
    for (NSProgress *p in _multiChildren) {
        [self stopObserving:p];
    }
}

- (NSArray *)childProgressArray {
    @synchronized (self) {
        return _multiChildren ? [NSArray arrayWithArray:_multiChildren] : nil;
    }
}

- (void)addChild:(NSProgress *)progress {
    NSParameterAssert(progress);
    
    @synchronized (self) {
        if (!_multiChildren) {
            _multiChildren = [NSMutableArray new];
        }
        
        if (![_multiChildren containsObject:progress]) {
            [_multiChildren addObject:progress];
            
            [progress addObserver:self forKeyPath:@"totalUnitCount" options:0 context:NULL];
            [progress addObserver:self forKeyPath:@"completedUnitCount" options:0 context:NULL];
            
            [self updateFromMultiChildren];
        }
    }
}

- (void)stopObserving:(NSProgress *)progress {
    [progress removeObserver:self forKeyPath:@"totalUnitCount" context:NULL];
    [progress removeObserver:self forKeyPath:@"completedUnitCount" context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    @synchronized (self) {
        if ([_multiChildren containsObject:object]) {
            [self updateFromMultiChildren];
        }
    }
}

- (void)removeChild:(NSProgress *)progress {
    NSParameterAssert(progress);
    
    @synchronized (self) {
        if ([_multiChildren containsObject:progress]) {
            [self stopObserving:progress];
            [_multiChildren removeObject:progress];
            [self updateFromMultiChildren];
        }
    }
}

// only call under lock
- (void)updateFromMultiChildren {
    int64_t completed = 0;
    int64_t total = 0;
    
    for (NSProgress *p in _multiChildren) {
        completed += MAX(0ll, p.completedUnitCount);
        total += MAX(0ll, p.totalUnitCount);
    }
    
    if (_multiChildren.count == 0) {
        self.localizedDescription = @"";
        self.totalUnitCount = 1;
        self.completedUnitCount = 1;
    } else {
        if (_multiChildren.count == 1) {
            self.localizedDescription = [_multiChildren[0] localizedDescription];
        } else {
            self.localizedDescription = [NSString localizedStringWithFormat:NSLocalizedString(@"Downloading %tu files …", nil), _multiChildren.count];
        }
        self.totalUnitCount = total;
        self.completedUnitCount = completed;
    }
}

- (void)cancel {
    @synchronized (self) {
        for (NSProgress *p in _multiChildren) {
            [p cancel];
        }
    }
}

@end

//
//  PRDiffFileBarViewController.m
//  ShipHub
//
//  Created by James Howard on 3/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "PRDiffFileBarViewController.h"

#import "GitDiff.h"
#import "Extras.h"

@interface PRDiffFileBarViewController ()

@property IBOutlet NSView *path1View;
@property IBOutlet NSView *path2View;

@property IBOutlet NSPathControl *pathControl;

@property IBOutlet NSPathControl *previousPathControl;
@property IBOutlet NSPathControl *currentPathControl;

@end

@implementation PRDiffFileBarViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.view setContentView:_path1View];
    
    _pathControl.pathItems = @[];
    _previousPathControl.pathItems = @[];
    _currentPathControl.pathItems = @[];
}

static NSArray *controlItemsForPath(NSString *path, DiffFileMode mode) {
    NSArray *components = [path pathComponents];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:components.count];
    for (NSUInteger i = 0; i+1 < components.count; i++) {
        NSPathControlItem *item = [NSPathControlItem new];
        item.title = components[i];
        item.image = [NSImage imageNamed:NSImageNameFolder];
        [items addObject:item];
    }
    
    NSPathControlItem *file = [NSPathControlItem new];
    NSString *lastComponent = [components lastObject];
    NSString *title = lastComponent;
    if (mode == DiffFileModeBlobExecutable) {
        title = [title stringByAppendingString:@" (+x)"];
    }
    file.title = title;
    file.image = [[NSWorkspace sharedWorkspace] iconForFileType:[lastComponent pathExtension]];
    
    [items addObject:file];
    
    return items;
}
    
static NSArray *componentCellsForPath(NSString *path, DiffFileMode mode) {
    NSArray *components = [path pathComponents];
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:components.count];
    for (NSUInteger i = 0; i+1 < components.count; i++) {
        NSPathComponentCell *cell = [NSPathComponentCell new];
        cell.stringValue = components[i];
        cell.image = [NSImage imageNamed:NSImageNameFolder];
        [items addObject:cell];
    }
    
    NSPathComponentCell *file = [NSPathComponentCell new];
    NSString *lastComponent = [components lastObject];
    NSString *title = lastComponent;
    if (mode == DiffFileModeBlobExecutable) {
        title = [title stringByAppendingString:@" (+x)"];
    }
    file.stringValue = title;
    file.image = [[NSWorkspace sharedWorkspace] iconForFileType:[lastComponent pathExtension]];
    
    [items addObject:file];
    
    return items;
}

- (void)setFile:(GitDiffFile *)file {
    static BOOL useDeprecatedSetPathComponentCells;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSOperatingSystemVersion vers = [[NSProcessInfo processInfo] operatingSystemVersion];
        useDeprecatedSetPathComponentCells = vers.majorVersion == 10 && vers.minorVersion < 12;
    });
    
    if (_file != file) {
        _file = file;
        
        if (file.oldPath && ![file.oldPath isEqualToString:file.path]) {
            if (!_path2View.superview) {
                [self.view setContentView:_path2View];
            }
            _previousPathControl.toolTip = file.oldPath;
            if (!useDeprecatedSetPathComponentCells) {
                _previousPathControl.pathItems = controlItemsForPath(file.oldPath, file.oldMode);
                _currentPathControl.pathItems = controlItemsForPath(file.path, file.mode);
            } else {
                [_previousPathControl setPathComponentCells:componentCellsForPath(file.oldPath, file.oldMode)];
                [_currentPathControl setPathComponentCells:componentCellsForPath(file.path, file.mode)];
            }
            _currentPathControl.toolTip = file.path;
        } else {
            if (!_path1View.superview) {
                [self.view setContentView:_path1View];
            }
            
            if (!useDeprecatedSetPathComponentCells) {
                _pathControl.pathItems = controlItemsForPath(file.path, file.mode);
            } else {
                [_pathControl setPathComponentCells:componentCellsForPath(file.path, file.mode)];
            }
            _pathControl.toolTip = file.path;
        }
    }
}

@end
